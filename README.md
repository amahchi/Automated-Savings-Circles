# Automated Savings Circles Smart Contract

A decentralized implementation of traditional rotating savings groups (tanda/chit fund/susu) on the Stacks blockchain using Clarity smart contracts.

## Overview

Automated Savings Circles digitizes the traditional concept of rotating savings groups where members contribute a fixed amount regularly, and each member receives the total pool once during the cycle. This smart contract automates the entire process, ensuring transparency, security, and trustless operation.

## Features

- **Trustless Operation**: No central authority needed; smart contract handles all logic
- **Flexible Group Sizes**: Support for 3-20 members per circle
- **Automated Payouts**: Weekly contribution cycles with systematic payouts
- **Transparent Records**: All contributions and payouts recorded on-chain
- **Platform Fee**: Small fee (2.5% default) for contract maintenance
- **Emergency Controls**: Admin functions for exceptional circumstances

## How It Works

1. **Circle Creation**: Anyone can create a savings circle by specifying:
   - Weekly contribution amount (in STX)
   - Maximum number of members (3-20)

2. **Joining**: Members join during the "forming" phase before the circle starts

3. **Contributing**: Once started, members contribute weekly amounts to the pool

4. **Payouts**: Each week, one member receives the total pool (minus platform fee)
   - Recipients are determined by join order
   - Each member receives exactly one payout during the cycle

5. **Completion**: Circle completes when all members have received their payout

## Contract Functions

### Public Functions

#### `create-circle (weekly-amount uint) (max-members uint)`
Creates a new savings circle with specified parameters.

**Parameters:**
- `weekly-amount`: STX amount each member contributes weekly
- `max-members`: Maximum members allowed (3-20)

**Returns:** Circle ID

#### `join-circle (circle-id uint)`
Join an existing circle during the forming phase.

**Requirements:**
- Circle must be in "forming" status
- Circle must not be full
- Sender must not already be a member

#### `start-circle (circle-id uint)`
Starts the contribution cycle (creator only).

**Requirements:**
- Caller must be circle creator
- Circle must have minimum members (3)
- Circle must be in "forming" status

#### `contribute (circle-id uint)`
Make weekly contribution to active circle.

**Requirements:**
- Circle must be active
- Sender must be a member
- Cannot contribute twice in same week

#### `distribute-payout (circle-id uint)`
Distributes weekly payout to designated recipient.

**Logic:**
- Calculates total pool from all contributions
- Deducts platform fee
- Transfers remaining amount to recipient
- Updates circle state

### Read-Only Functions

#### `get-circle (circle-id uint)`
Returns circle information including status, amounts, and member count.

#### `get-member-info (circle-id uint) (member principal)`
Returns member-specific information including contribution history.

#### `get-current-week (circle-id uint)`
Calculates current week number for active circles.

#### `calculate-platform-fee (amount uint)`
Calculates platform fee for given amount.

## Circle States

- **STATUS-FORMING (0)**: Accepting new members
- **STATUS-ACTIVE (1)**: Weekly contributions and payouts active
- **STATUS-COMPLETED (2)**: All members received payouts
- **STATUS-CANCELLED (3)**: Emergency cancellation

## Error Codes

| Code | Description |
|------|-------------|
| 100 | Not authorized |
| 101 | Circle not found |
| 102 | Already a member |
| 103 | Circle is full |
| 104 | Circle already started |
| 105 | Invalid amount |
| 106 | Payment late |
| 107 | Not a member |
| 108 | Already received payout |
| 109 | Circle not started |
| 110 | Insufficient funds |

## Usage Example

```clarity
;; Create a circle: 100 STX weekly, max 5 members
(contract-call? .savings-circles create-circle u100000000 u5)

;; Join circle #1
(contract-call? .savings-circles join-circle u1)

;; Start circle (creator only)
(contract-call? .savings-circles start-circle u1)

;; Make weekly contribution
(contract-call? .savings-circles contribute u1)

;; Distribute payout (anyone can call)
(contract-call? .savings-circles distribute-payout u1)
```

## Security Considerations

- **Funds Security**: All STX contributions held in contract until payout
- **Access Control**: Only authorized users can perform sensitive operations
- **State Validation**: Comprehensive checks prevent invalid state transitions
- **Emergency Controls**: Admin can cancel circles in exceptional circumstances
- **No Reentrancy**: Functions designed to prevent reentrancy attacks

## Platform Economics

- **Platform Fee**: 2.5% of each payout (adjustable by admin)
- **Fee Distribution**: Platform fees go to contract owner for maintenance
- **Member Benefits**: 97.5% of contributions returned to members
- **Transparency**: All fees calculated and recorded on-chain

## Development

### Prerequisites
- Clarinet CLI for testing and deployment
- Stacks wallet for interaction
- STX tokens for contributions

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy --testnet
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Submit pull request

## License

MIT License - see LICENSE file for details

## Support

For questions or issues:
- Open GitHub issue
- Contact development team
- Check Stacks documentation

## Roadmap

- [ ] Mobile app integration
- [ ] Multi-token support (SIP-010 tokens)
- [ ] Governance token for platform decisions
- [ ] Insurance mechanisms for defaults
- [ ] Integration with DeFi protocols
