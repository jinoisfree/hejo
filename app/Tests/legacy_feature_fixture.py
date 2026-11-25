"""An old gate rejects optional feature queries while preserving existing fixture assertions."""
async def reject_telegram(ws, frame):
    if frame.get('type') not in {'telegram', 'discord'}:
        return False
    await ws.send_json({'v': 1, 'type': 'error', 'ref': frame['id'], 'code': 'unexpected_frame'})
    return True


async def receive_legacy(ws):
    while True:
        frame = await ws.receive_json()
        if not await reject_telegram(ws, frame):
            return frame
