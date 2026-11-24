import { text } from 'node:stream/consumers';
import { createInterface } from 'node:readline';

async function readReply(provider, requestedId) {
    let sessionId;
    let reply;
    let completed = false;
    let lastError;
    const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });
    for await (const line of lines) {
        if (!line.trim()) continue;
        let event;
        try {
            event = JSON.parse(line);
        } catch {
            // A stray log line must not discard a long-running turn.
            console.error(`${provider}: ignored non-JSON output: ${line.slice(0, 200)}`);
            continue;
        }
        if (provider === 'agy') {
            if (event.event !== 'result') continue;
            const result = event.result;
            if (result.status !== 'SUCCESS') throw new Error(result.error || result.status);
            sessionId = result.conversation_id;
            reply = result.response;
            completed = true;
        } else {
            switch (event.type) {
                case 'thread.started':
                    sessionId = event.thread_id;
                    // Report the ID before the turn ends so that a stopped run can be resumed.
                    console.error(`codex: session_id ${sessionId}`);
                    break;
                case 'item.completed':
                    if (event.item.type === 'agent_message') reply = event.item.text;
                    break;
                case 'error':
                    lastError = event.message;
                    break;
                case 'turn.failed':
                    throw new Error(event.error?.message || lastError || 'Codex turn failed');
                case 'turn.completed':
                    completed = true;
                    break;
            }
        }
    }
    if (!completed || !sessionId || typeof reply !== 'string' || !reply.trim()) {
        throw new Error(lastError || 'Missing completed turn, session ID or reply');
    }
    if (requestedId && sessionId !== requestedId) {
        throw new Error(`Requested session ${requestedId}, received ${sessionId}`);
    }
    return { session_id: sessionId, reply };
}

const [mode, requestedId] = process.argv.slice(2);
try {
    if (mode === 'agy-input') {
        const content = await text(process.stdin);
        console.log(JSON.stringify({ event: 'user', message: { content } }));
    } else if (mode === 'agy' || mode === 'codex') {
        console.log(JSON.stringify(await readReply(mode, requestedId)));
    } else {
        throw new Error('Expected agy-input, agy or codex');
    }
} catch (error) {
    console.error(`${mode}: ${error.message}`);
    process.exitCode = 1;
}
