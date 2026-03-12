// JAM SDK - Authorizer Entry Point
// Only include this file in authorizer builds.
module jam::entry_auth;

import jam::types;
import jam::codec;
import jam::log;

// User hook
extern fn void is_authorized(types::IsAuthorizedArgs* args);

fn void jam_entry_is_authorized(char* arg_ptr, ulong arg_len) @export("jam_entry_is_authorized")
{
    codec::DecodeCtx ctx = codec::decode_ctx_init(arg_ptr, arg_len);

    types::IsAuthorizedArgs args;

    ushort? ci = codec::decode_var_u16(&ctx);
    if (catch ci)
    {
        log::err("JAM", "Authorizer: failed to decode core_index");
        return;
    }
    args.core_index = ci;

    is_authorized(&args);
}
