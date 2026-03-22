# Deploying

Once you have built a `.jam` blob, you need to deploy it to a JAM chain. This section covers running a local testnet, deploying services, and submitting work packages.

## Deployment workflow

```
1. Build your service     ->  build/my_service.jam
2. Start a local testnet  ->  JAM nodes running locally
3. Deploy the service     ->  Service gets an on-chain ID
4. Submit work packages   ->  Triggers refine + accumulate
```

## Tools

- **jam-cli** -- command-line tool for interacting with JAM chains. Used to deploy services and submit work packages.
- **jamt** / **polkajam** -- local testnet runners that spin up JAM validator nodes.

## Sections

- [Running a Local Testnet](./local-testnet.md) -- set up a local JAM chain for development.
- [Deploying a Service](./deploy-service.md) -- deploy your `.jam` blob on-chain.
- [Submitting Work Packages](./submit-work.md) -- send work items to your deployed service.
