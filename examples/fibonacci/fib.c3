// Example: Fibonacci JAM Service
module fib;

import jam::codec;
import jam::log;
import jam::types;
import jam::refine;
import jam::accumulate;

fn types::RefineResult refine(refine::Ctx* ctx) @export("refine") {
  log::debug_u64("fib", "Refine: entry, service: ", ctx.service_id());

  ulong value = 10;
  if (ctx.payload() == null || ctx.payload_len() == 0)
  {
    log::warn("fib", "Refine: empty payload. Calculating default value=10");
  } else {
    codec::DecodeCtx dec = codec::decode_ctx_init(ctx.payload(), ctx.payload_len());
    ulong? decoded = codec::decode_u8(&dec);
    if (catch decoded)
    {
      log::warn("fib", "Refine: failed to decode payload. Calculating default value=10");
    } else {
      value = decoded;
    }
  }

  ulong result = fib_calc(value);
  log::debug_u64("fib", "Refine: result ", result);

  char[8] buf;
  if (catch codec::encode_u64(&buf, 8, result)) { return ctx.result_empty(); }
  return ctx.result_ok(&buf, 8);
}

fn void accumulate(accumulate::Ctx* ctx) @export("accumulate") {}

fn ulong fib_calc(ulong n) {
  ulong a;
  ulong b = 1;

  for (ulong i; i < n; i++) {
    ulong t = a + b;
    a = b;
    b = t;
  }

  return a;
}
