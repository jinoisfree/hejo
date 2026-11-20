"""An old gate rejects the new optional query while preserving existing fixture assertions."""
async def reject_imessage(ws, frame):
    if frame.get('type') != 'imessage':
        return False
    await ws.send_json({'v': 1, 'type': 'error', 'ref': frame['id'], 'code': 'unexpected_frame'})
    return True


async def receive_legacy(ws):
    while True:
        frame = await ws.receive_json()
        if not await reject_imessage(ws, frame):
            return frame
