"""Foundation search with grapheme offsets for bounded UI snippets.

Room search uses the client's locale; workspace snippets use the canonical
locale, as WorkspaceSearch.highlights does. This is not collation searching:
width, accents and ignorable punctuation must remain distinguishable.
"""
import ctypes
from ctypes.util import find_library
from contextlib import ExitStack
import unicodedata
import regex
from .history import HistoryError


class CFRange(ctypes.Structure):
    _fields_ = [('location', ctypes.c_long), ('length', ctypes.c_long)]


# Reuse the same Foundation search implementation as the Mac app. ICU collation
# differs for ligatures, width and emoji; do not substitute it silently.
_library = find_library('CoreFoundation')
_cf = ctypes.CDLL(_library) if _library else None
if _cf is not None:
    _cf.CFStringCreateWithBytes.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32, ctypes.c_bool]
    _cf.CFStringCreateWithBytes.restype = ctypes.c_void_p
    _cf.CFLocaleCreate.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    _cf.CFLocaleCreate.restype = ctypes.c_void_p
    _cf.CFRelease.argtypes = [ctypes.c_void_p]
    _cf.CFRelease.restype = None
    _cf.CFStringFindWithOptionsAndLocale.argtypes = [ctypes.c_void_p, ctypes.c_void_p, CFRange, ctypes.c_ulong, ctypes.c_void_p, ctypes.POINTER(CFRange)]
    _cf.CFStringFindWithOptionsAndLocale.restype = ctypes.c_bool


def available():
    return _cf is not None


def clusters(text):
    return regex.findall(r'\X', text)


def ranges(text, query, locale=''):
    if not available():
        raise HistoryError('unavailable', 503)
    if not query or not text:
        return []
    with ExitStack() as owned:
        def string(value):
            data = value.encode('utf-8')
            pointer = _cf.CFStringCreateWithBytes(None, data, len(data), 0x08000100, False)
            if not pointer:
                raise HistoryError('unavailable', 503)
            owned.callback(_cf.CFRelease, pointer)
            return pointer
        haystack, needle = string(text), string(query)
        location = None
        if locale:
            location = _cf.CFLocaleCreate(None, string(locale))
            if not location:
                raise HistoryError('invalid_query')
            owned.callback(_cf.CFRelease, location)
        characters = clusters(text)
        boundaries, length = [0], 0
        for character in characters:
            length += len(character.encode('utf-16-le'))//2
            boundaries.append(length)
        from bisect import bisect_right, bisect_left
        result, offset = [], 0
        while offset < length:
            match = CFRange()
            # kCFCompareCaseInsensitive | kCFCompareNonliteral; NSString search
            # uses canonical matching by default, unlike literal CF searches.
            if not _cf.CFStringFindWithOptionsAndLocale(haystack, needle, CFRange(offset, length-offset), 1 | 16, location, ctypes.byref(match)):
                break
            start = bisect_right(boundaries, match.location)-1
            end = bisect_left(boundaries, match.location+match.length)
            result.append((start, end))
            offset = boundaries[start+1]
        return result


def snippet(text, query):
    term = unicodedata.normalize('NFC', query.strip()).lower()
    found = ranges(text, term)
    if not found:
        found = [span for word in term.split() for span in ranges(text, word)]
    characters = clusters(text)
    if not found:
        return ''.join(characters[:60])
    # Existing highlights merges touching/overlapping spans before taking first.
    merged = []
    for start, end in sorted(found):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(end, merged[-1][1]))
        else:
            merged.append((start, end))
    begin, end = max(0, merged[0][0]-30), min(len(characters), merged[0][1]+30)
    return ('…' if begin else '') + ''.join(characters[begin:end]).replace('\n', ' ') + ('…' if end < len(characters) else '')
