# Running a Local Testnet

Before deploying to a public JAM network, you will want to test your service on a local testnet. A local testnet runs one or more JAM validator nodes on your machine.

## Options

There are several JAM node implementations you can use for local development:

- **jamt** -- a JAM testnet runner
- **polkajam** -- Polkadot's JAM implementation
- Other JAM-compatible node implementations

## Starting a testnet

The exact commands depend on which node implementation you use. A typical setup looks like:

```bash
# Example with a JAM node (commands vary by implementation)
jam-node --dev --rpc-port 19800
```

The key thing is to note the **RPC endpoint** (typically `ws://localhost:19800`). You will need this for deploying services and submitting work.

## Verifying the testnet

Once your testnet is running, verify connectivity:

```bash
# Check if the node is reachable
jam-cli --rpc ws://localhost:19800 status
```

You should see information about the running chain, including the current timeslot and number of cores.

## Development workflow

A typical development loop looks like:

1. Start the local testnet (once).
2. Edit your C3 source code.
3. Build with `jam-build`.
4. Deploy with `jam-cli deploy-service`.
5. Submit a work package with `jam-cli submit-work`.
6. Check logs and storage to verify behavior.
7. Repeat from step 2.

The local testnet persists between deployments, so you can iterate quickly without restarting it each time.

## Multiple validators

For testing features that require consensus (like work report attestation), you may need to run multiple validator nodes. Consult the documentation for your chosen node implementation for details on multi-validator setups.
