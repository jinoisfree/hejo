"""Bounded plain conversation context shared by branches and room delivery."""
import re


def split_text(text, byte_limit):
    """Lossless UTF-8 chunks, preferring complete lines within the wire bound."""
    chunks = []
    while len(text.encode("utf-8")) > byte_limit:
        prefix = text.encode("utf-8")[:byte_limit].decode("utf-8", errors="ignore")
        end = prefix.rfind("\n") + 1 or len(prefix)
        chunks.append(text[:end])
        text = text[end:]
    return chunks + [text]


def thinking(text):
    return bool(re.fullmatch(r"[◐◓◑◒🤔\s]*생각\s*중\s*(?:\.{2,}|…)?\s*", text.split("\n", 1)[0]))


def conversation_lines(messages, names, *, limit, characters, line_characters):
    lines = []
    for row in messages:
        if row["role"] != "owner" and thinking(row["text"]):
            continue
        name = "나" if row["role"] == "owner" else names.get(row["employee"], row["employee"])
        body = row["text"].replace("\n", " ")[:line_characters]
        attachments = " ".join("📎" + entry["name"] for entry in row.get("files", []))
        lines.append(name + ": " + body + (" " + attachments if attachments else ""))
    # Select newest complete lines first; a single long line is clipped at the total bound.
    selected, remaining = [], characters
    for line in reversed(lines[-limit:]):
        if remaining <= 0:
            break
        piece = line[:remaining]
        selected.append(piece)
        remaining -= len(piece) + 1
    return "\n".join(reversed(selected))


def with_context(context, text, heading):
    return f"[{heading}]\n{context}\n\n[이번 글]\n{text}" if context else text
