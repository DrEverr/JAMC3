// Example: Hello World JAM Service
// Minimal structure for a JAM service in C3.
module hello;

import jam::types;
import jam::service;
import jam::log;

// ---------------------------------------------------------------------------
// Refine - off-chain computation
// ---------------------------------------------------------------------------

fn types::RefineResult refine(types::RefineArgs* args) @export("refine")
{
    log::info("hello", "Hello World from Refine!");

    char[5] result = { 'h', 'e', 'l', 'l', 'o' };
    return service::refine_ok(&result, 5);
}

// ---------------------------------------------------------------------------
// Accumulate - on-chain computation
// ---------------------------------------------------------------------------

fn void accumulate(types::AccumulateArgs* args) @export("accumulate")
{
    log::info("hello", "Hello World from Accumulate!");
}
