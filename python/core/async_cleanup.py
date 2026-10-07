import asyncio


async def finish_cleanup(coro):
    """Finish bounded cleanup before propagating cancellation of its caller.

    A separate worker prevents repeated caller cancellation from cancelling
    handle.close() halfway through. Callers must keep each cleanup phase bounded
    and exclude the initiating task from their tracked-task cancellation set.
    """
    worker = asyncio.create_task(coro)
    cancelled = None
    while not worker.done():
        try:
            await asyncio.shield(worker)
        except asyncio.CancelledError as exc:
            if worker.cancelled():
                raise
            if cancelled is None:
                cancelled = exc
    result = worker.result()
    if cancelled is not None:
        raise cancelled
    return result
