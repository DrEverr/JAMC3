# Deploying a Service

Once you have a `.jam` blob and a running testnet, you can deploy your service on-chain using `jam-cli`.

## Basic deployment

```bash
jam-cli --rpc ws://localhost:19800 deploy-service \
  --jam-file build/my_service.jam
```

This uploads your service code to the chain and creates a new service account. On success, `jam-cli` prints the assigned **service ID**.

## Deployment process

When you deploy a service, the following happens:

1. The `.jam` blob is submitted as a transaction.
2. The chain validates the code and creates a new service account.
3. A service ID is assigned (a 32-bit integer).
4. The service's code hash, balance, and metadata are stored on-chain.

## Funding the service

Services need a token balance to pay for storage deposits and gas. Depending on your testnet setup, newly deployed services may receive an initial balance automatically, or you may need to fund them separately:

```bash
jam-cli --rpc ws://localhost:19800 transfer \
  --to <service-id> \
  --amount 1000000
```

## Checking service status

After deployment, verify that your service exists on-chain:

```bash
jam-cli --rpc ws://localhost:19800 service-info \
  --id <service-id>
```

This shows the service's code hash, balance, storage usage, and other metadata, corresponding to the `ServiceInfo` struct in the SDK.

## Upgrading a service

To update your service's code, redeploy with the new `.jam` blob. The `upgrade` host function (called during accumulate) replaces the service's code hash:

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    types::Hash new_code_hash = { /* ... */ };
    ctx.upgrade(&new_code_hash, 100000, 100000);
}
```

In practice, you typically deploy a new version as a separate service during development.

## Authorizer deployment

Deploy an authorizer the same way:

```bash
jam-build --authorizer my_auth.c3
jam-cli --rpc ws://localhost:19800 deploy-service \
  --jam-file build/my_auth.jam
```

After deploying, assign the authorizer to a core so it can approve work packages:

```c
// Inside the assigner service's accumulate
ctx.assign(core_index, &authorizer_hashes, assigner_id)!;
```
