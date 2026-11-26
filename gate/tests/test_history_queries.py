"""Independent small cases for complete-thread semantics and search candidate limits."""
import pytest
from gate.history import HistoryContext, HistoryIndex
from gate.history_queries import HistoryQueries, prefix, assess


def make_context(**changes):
    return HistoryContext({'session':'fixture','generation':1,'memberRevision':0,'ready':True,
        'items':{},'home':['alpha'],'hidden':[],'names':{'alpha':'Alpha'},'now':1767225600,**changes},{'alpha'})


def post(seq, **extra):
    return {'v':1,'type':'message','seq':seq,'msg_id':f'fixture-{seq}','employee':'alpha',
            'thread':'fixture-thread','role':'employee','text':'fixture','files':[],
            'buttons':[],'reply_state':None,'ts':'2026-01-01T00:00:00Z',**extra}


def test_grapheme_prefix_does_not_split_combining_hangul_or_emoji():
    value='한'+'👩🏽‍💻'+'e\u0301'+'끝'
    assert prefix(value,1)=='한'
    assert prefix(value,2)=='한👩🏽‍💻'
    assert prefix(value,3)=='한👩🏽‍💻e\u0301'


def test_targeted_answer_leaves_earlier_buttons_waiting():
    lines=[post(1,text='첫 질문',buttons=[{'id':'fixture-button'}]),post(2,text='승인해 줘'),
           post(3,role='owner',text='승인',answer_to='fixture-2'),post(4,text='처리했어요')]
    result,buttons,_=assess(lines,make_context())
    assert result=={'requestID':'fixture-1','pendingID':'fixture-1','working':False,'settled':False,'approved':False}
    assert buttons=={'fixture-1'}
    result,_,_=assess(lines[1:],make_context())
    assert result['settled'] and result['pendingID'] is None


@pytest.mark.parametrize(('final', 'settled'), [(False, False), (True, True), (None, True)])
def test_free_text_answer_settles_after_completed_employee_reply(final, settled):
    lines = [post(1, text='승인해 줘'), post(2, role='owner', text='문구를 수정해 주세요'),
             post(3, **({} if final is None else {'final': final}))]
    state, _, _ = assess(lines, make_context())
    assert state['settled'] is settled
    assert not state['approved']


@pytest.mark.asyncio
async def test_24h_and_original_read_boundary_survive_edit():
    index=HistoryIndex()
    index.apply(post(1,text='알림'))
    context=make_context(items={'read:alpha':{'v':'1','at':0,'dev':'fixture'}})
    query=HistoryQueries(index,context)
    first=await query.summary(('alpha','fixture-thread'))
    assert first['unread']==0 and first['notice']['id']=='fixture-1'
    index.apply({'v':1,'type':'edit','seq':2,'msg_id':'fixture-1','text':'수정된 알림'})
    second=await query.summary(('alpha','fixture-thread'))
    assert second['unread']==0 and second['originalMaxSeq']==1 and second['latestSeq']==2
    expired=await HistoryQueries(index,make_context(now=1767312000)).summary(('alpha','fixture-thread'))
    assert expired['notice'] is None


@pytest.mark.asyncio
async def test_candidate_200_before_grouping_and_sidebar_30():
    index=HistoryIndex()
    # Static search boundary fixture only; no AppKit/performance workload.
    for i in range(1,202):
        index.apply(post(i,msg_id=f'fixture-{i:03}',thread=f'fixture-thread-{i}',text='검색'))
    query=HistoryQueries(index,make_context())
    groups=await query.search('검색',['alpha'],'groups')
    assert len(groups)==200
    assert {m['id'] for group in groups for m in group['matches']}=={f'fixture-{i:03}' for i in range(2,202)}
    sidebar=await query.search('검색',['alpha'],'sidebar')
    assert [m['id'] for m in sidebar]==[f'fixture-{i:03}' for i in range(201,171,-1)]


@pytest.mark.asyncio
async def test_sidebar_preserves_hidden_and_thinking_difference():
    index=HistoryIndex();index.apply(post(1,text='생각 중...'))
    query=HistoryQueries(index,make_context(hidden=['alpha']))
    assert await query.search('생각',['alpha'],'groups')==[]
    assert [m['id'] for m in await query.search('생각',['alpha'],'sidebar')]==['fixture-1']


@pytest.mark.asyncio
async def test_room_search_uses_body_locale_and_returns_thread_order():
    index = HistoryIndex()
    index.apply(post(1, text='Istanbul', thread='one'))
    index.apply(post(2, text='istanbul', thread='two'))
    index.apply(post(3, text='unrelated', thread='three', files=[{'name':'Istanbul'}]))
    query = HistoryQueries(index, make_context(locale='tr_TR'))
    assert [row['key']['thread'] for row in await query.search('ıstan', ['alpha'], 'room')] == ['one']
    assert [row['key']['thread'] for row in await query.search('istan', ['alpha'], 'room')] == ['two']
    index.apply({'type':'edit','seq':4,'msg_id':'fixture-1','text':'istanbul'})
    assert [row['key']['thread'] for row in await query.search('istan', ['alpha'], 'room')] == ['one','two']


def test_search_character_boundaries_and_snippet_window():
    from gate.history_search import ranges, snippet
    assert ranges('Straße','STRASSE') == [(0,6)]
    for text,query in [('ＡＢＣ','abc'),('👩🏽‍💻','👩'),('café','cafe'),('ß','s')]:
        assert not ranges(text,query)
    assert snippet('앞'*50+'검색'+'뒤'*50,'검색') == '…'+'앞'*30+'검색'+'뒤'*30+'…'
    assert snippet('한글 내용','한글') == '한글 내용'


@pytest.mark.asyncio
async def test_sidebar_activity_uses_timestamp_not_edit_revision():
    index = HistoryIndex()
    index.apply(post(1, ts='2026-01-01T00:00:00Z'))
    query = HistoryQueries(index, make_context())
    assert (await query.summary(('alpha','fixture-thread')))['sidebarActivity'] == 1767225600
    index.apply({'type':'edit','seq':2,'msg_id':'fixture-1','text':'edited'})
    assert (await query.summary(('alpha','fixture-thread')))['sidebarActivity'] == 1767225600
    index.apply(post(3, ts='invalid'))
    assert (await query.summary(('alpha','fixture-thread')))['sidebarActivity'] == 1767225600


@pytest.mark.asyncio
async def test_search_presentation_is_not_a_body_and_preserves_notes():
    index = HistoryIndex()
    index.apply(post(1, text='앞'*50+'찾기'+'뒤'*50))
    index.apply(post(2, text='본문', files=[{'name':'찾기.txt'}], role='owner'))
    query = HistoryQueries(index, make_context())
    group = (await query.search('찾기', ['alpha'], 'groups'))[0]
    assert group['rootSnippet'] == '…'+'앞'*30+'찾기'+'뒤'*30+'…'
    hit = group['matches'][0]
    assert hit['notes'] == ['📎 찾기.txt']
    assert hit['snippet'] == '본문' and hit['role'] == 'owner' and hit['speaker'] == 'alpha'
    assert hit['timestamp'] == '2026-01-01T00:00:00Z'
    assert hit['key'] == {'room':'alpha','thread':'fixture-thread'}
    assert not {'type','text','files','msg_id'} & hit.keys()
    body_match = group['matches'][1]
    assert body_match['notes'] == []


@pytest.mark.asyncio
async def test_island_questions_are_not_notice_candidates():
    index = HistoryIndex()
    index.apply(post(1, text='first question', reply_state='asked'))
    index.apply(post(2, role='owner', text='answer'))
    index.apply(post(3, text='생각 중...', reply_state='asked'))
    index.apply(post(4, text='confirmed', reply_state='asked', thread='other'))
    context = make_context(items={'confirm:fixture-4':{'v':'1','at':0,'dev':'fixture'}})
    query = HistoryQueries(index, context)
    questions = await query.questions(['alpha'])
    assert [q['id'] for q in questions] == ['fixture-1','fixture-3']
    assert questions[1]['preview'] == '생각 중...'
    assert all('text' not in q and 'type' not in q for q in questions)
    assert 'fixture-1' not in [n['id'] for n in query.notices(await query.summaries(['alpha']))]
    index.apply({'type':'edit','seq':5,'msg_id':'fixture-1','reply_state':'answered'})
    assert [q['id'] for q in await query.questions(['alpha'])] == ['fixture-3']


@pytest.mark.asyncio
async def test_activity_preserves_last_employee_and_finalized_thinking():
    index=HistoryIndex()
    index.apply(post(1,room='fixture-group',employee='alpha',text='first'))
    index.apply(post(2,room='fixture-group',employee='beta',text='생각 중...'))
    index.apply(post(3,room='fixture-group',role='owner',employee='alpha',text='reply'))
    query=HistoryQueries(index,make_context())
    key=('fixture-group','fixture-thread')
    assert (await query.summary(key))['activity']=={'lastSpeaker':'beta','working':True,'latestEmployeeTime':1767225600.0}
    index.apply({'v':1,'type':'edit','seq':4,'msg_id':'fixture-2','text':'생각 중...','final':True})
    assert (await query.summary(key))['activity']['working'] is False
    index.apply({'v':1,'type':'edit','seq':5,'msg_id':'fixture-2','text':'answer','final':False})
    assert (await query.summary(key))['activity']['working'] is True
    index.apply({'v':1,'type':'delete','seq':6,'msg_id':'fixture-2'})
    assert (await query.summary(key))['activity']['lastSpeaker']=='alpha'
    index.apply({'v':1,'type':'delete','seq':7,'msg_id':'fixture-1'})
    assert (await query.summary(key))['activity']=={'lastSpeaker':None,'working':False,'latestEmployeeTime':None}


ALERT_PREVIEWS = [
    pytest.param('@acct \n요약: 가짜', False, '@acct · 요약: 가짜', id='trailing-space'),
    pytest.param('  @a @b\t\n본문', False, '@a @b · 본문', id='surrounding-space'),
    pytest.param('@acct\n\n요약: 가짜 소식 하나', False, '@acct · 요약: 가짜 소식 하나', id='single'),
    pytest.param('@a @b\n본문 줄', False, '@a @b · 본문 줄', id='multiple'),
    pytest.param('@acct 안녕하세요\n둘째 줄', False, '@acct 안녕하세요', id='inline'),
    pytest.param('@acct', False, '@acct', id='no-next-line'),
    pytest.param('@acct\n\n', False, '@acct', id='blank-next-lines'),
    pytest.param('보고 제목\n둘째 줄', False, '보고 제목', id='ordinary'),
    pytest.param('@ 본문\n둘째', False, '@ 본문', id='bare-at'),
    pytest.param('@acct\n' + '한' * 400, False, '@acct · ' + '한' * 292, id='capped-graphemes'),
    pytest.param('@acct\n질문 줄', True, '@acct · 질문 줄', id='question'),
]


async def alert_preview_rows(text, asked):
    index = HistoryIndex()
    index.apply(post(1, text=text, reply_state='asked' if asked else None))
    query = HistoryQueries(index, make_context())
    return await query.summary(('alpha', 'fixture-thread')), await query.questions(['alpha'])


@pytest.mark.asyncio
@pytest.mark.parametrize(('text', 'asked', 'expected'), ALERT_PREVIEWS)
async def test_alert_seen_notice_preview_at_as_09(text, asked, expected):
    summary, _ = await alert_preview_rows(text, asked)
    assert summary['notice']['questions'] is asked
    assert summary['notice']['preview'] == expected


@pytest.mark.asyncio
@pytest.mark.parametrize(('text', 'asked', '_expected'), ALERT_PREVIEWS)
async def test_alert_seen_other_previews_at_as_10(text, asked, _expected):
    summary, questions = await alert_preview_rows(text, asked)
    # All fixture clusters are single code points except deliberately decomposed Hangul.
    clusters = text.replace('한', '한')
    def first(length):
        return clusters[:length].replace('한', '한') if '한' in text else clusters[:length]
    assert summary['title'] == first(48).replace('\n', ' ')
    assert summary['preview'] == first(80)
    assert summary['rootPreview'] == first(240)
    if asked:
        assert [row['preview'] for row in questions] == [text.splitlines()[0][:24]]
    else:
        assert questions == []


def test_alert_seen_has_one_direct_selection_entry_at_as_08():
    import re
    from pathlib import Path

    sources = Path(__file__).resolve().parents[2] / 'app' / 'Sources'
    references = []
    for path in sources.glob('*.swift'):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if re.search(r'\bmarkAlertSeen\s*\(', line):
                references.append((path.name, number, line))
    definitions = [ref for ref in references if 'func markAlertSeen' in ref[2]]
    calls = [ref for ref in references if ref not in definitions]
    assert len(definitions) == len(calls) == 1, references
    path, number, _ = calls[0]
    source = (sources / path).read_text()
    owner = re.findall(r'^    (?:private )?func (\w+)\(', '\n'.join(source.splitlines()[:number]), re.M)[-1]
    view = (sources / 'ConversationView.swift').read_text()

    def method(name):
        return re.search(rf'^    (?:private )?func {name}\(.*?^    }}', view, re.M | re.S)[0]

    for name in ('reveal', 'chooseThread', 'writeReply'):
        assert re.search(rf'\b{owner}\(', method(name)), name
    for name in ('selectAutomatic', 'entry', 'createThread', 'refresh'):
        assert not re.search(rf'\b{owner}\(', method(name)), name
    if '원문 불러오기' in view:
        assert re.search(rf'\b{owner}\(', method('unloadedThreadContent'))


@pytest.mark.asyncio
async def test_alert_seen_island_preview_caps_the_original_first_line_at_as_10():
    _, questions = await alert_preview_rows('@' + 'a' * 30 + '\nsecond line', True)
    assert [row['preview'] for row in questions] == ['@' + 'a' * 23]
