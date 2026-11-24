from app.services import conversations


async def test_history_drops_blank_text_blocks_only(session):
    conv = await conversations.create_conversation(session)
    await conversations.append_message(session, conv.id, "user", [{"type": "text", "text": "  \n"}])
    await conversations.append_message(
        session, conv.id, "user", [{"type": "text", "text": ""}, {"type": "text", "text": "Hi"}]
    )
    tool_use = {"type": "tool_use", "id": "toolu_1", "name": "search", "input": {}}
    await conversations.append_message(session, conv.id, "assistant", [{"type": "text", "text": " "}, tool_use])
    result = {"type": "tool_result", "tool_use_id": "toolu_1", "content": ""}
    await conversations.append_message(session, conv.id, "user", [result])

    history = await conversations.history(session, conv.id)
    assert history == [
        {"role": "user", "content": [{"type": "text", "text": "Hi"}]},
        {"role": "assistant", "content": [tool_use]},
        {"role": "user", "content": [result]},
    ]
