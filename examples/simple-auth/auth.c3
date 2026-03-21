// Example: Simple Authorizer
// Minimal authorizer that always approves.
module simple_auth;

import jam::authorizer;
import jam::log;

fn void is_authorized(authorizer::Ctx* ctx) @export("is_authorized")
{
    log::info("auth", "Authorizer: approving request");
}
