# Work Packages

A **work package** is a bundle of work items submitted to the JAM network for processing. Work packages are the primary mechanism for sending computation to services.

## Structure

A work package contains:

- An **authorizer hash** identifying which authorizer must approve execution.
- One or more **work items**, each targeting a specific service.
- A **work package hash** (32 bytes) computed over the entire package.

Each work item within a package specifies:
- The target **service ID**.
- A **payload** (arbitrary bytes) that the service's refine function will process.
- A **gas limit** for the refine computation.

## Processing flow

```
  Submit work package
         |
         v
  Authorization check (is_authorized)
         |
         v
  Refine each work item (off-chain, parallel)
         |
         v
  Work reports (contain work digests)
         |
         v
  Accumulate (on-chain, sequential)
```

1. A work package is submitted to the network and assigned to a core.
2. The authorizer service's `is_authorized` function checks whether the package is allowed.
3. Each work item is refined independently. The refine function receives the payload and produces a work digest.
4. Validators attest to the results. Once enough attestations are collected, the work digests are included in a block.
5. The accumulate function receives the work digests (and any deferred transfers) as inputs.

## Accessing work items in refine

Inside `refine`, the context provides access to the current work item:

```c
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    // Which core is running this work item
    types::CoreIndex core = ctx.core_index();

    // Index of this work item within the package
    uint index = ctx.work_item_index();

    // The work item payload bytes
    char* payload = ctx.payload();
    ulong payload_len = ctx.payload_len();

    // Hash of the entire work package
    types::Hash* pkg_hash = ctx.work_package_hash();

    // Process the payload and return a result
    return ctx.result_ok(payload, (usz)payload_len);
}
```

## Receiving results in accumulate

In `accumulate`, you iterate over inputs. Each input is either an **operand** (a refined work digest) or a **transfer** (a deferred token transfer from another service):

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    accumulate::InputIter iter = ctx.inputs();

    while (true)
    {
        types::AccumulateInput? maybe = iter.next();
        if (catch maybe) break;
        types::AccumulateInput input = maybe;

        if (input.kind == types::AccumulateInputKind.OPERAND)
        {
            // This is a refined work digest
            types::AccumulateOperand op = input.operand;

            if (op.digest_output.status == types::WorkDigestStatus.OK)
            {
                // Access the refined output data
                char* data = op.digest_output.data;
                ulong len  = op.digest_output.data_len;

                // Process the result...
            }
        }
        else if (input.kind == types::AccumulateInputKind.TRANSFER)
        {
            // This is a deferred transfer
            types::AccumulateTransfer xfer = input.transfer;
            // xfer.sender, xfer.amount, xfer.memo, etc.
        }
    }
}
```

## Work digest statuses

When a work item's refine function executes, the result carries a status:

| Status | Meaning |
|--------|---------|
| `OK` | Refine completed successfully; output data is available |
| `OUT_OF_GAS` | Refine ran out of gas |
| `PANIC` | Refine panicked |
| `BAD_EXPORTS` | Invalid export segments |
| `OVERSIZE` | Output exceeded size limit |
| `BAD_CODE` | Service code could not be loaded |
| `BIG_CODE` | Service code exceeded size limit |

Only `OK` status includes output data. For all other statuses, `data` is null and `data_len` is zero.
