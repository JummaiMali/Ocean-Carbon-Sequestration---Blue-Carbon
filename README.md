A Stacks blockchain smart contract for tokenizing verified blue carbon credits from ocean-based restoration projects.

## 🌱 Features

- 🏝️ **Project Registration**: Register mangrove, seagrass, and kelp forest restoration projects
- 🛰️ **Oracle Verification**: Satellite and oracle-based project verification system
- 🪙 **Carbon Credit Tokenization**: Mint fungible blue carbon credit tokens
- 🛒 **Marketplace**: Create and execute buy/sell orders for carbon credits
- 📊 **Transparency**: Public tracking of all restoration projects and transactions

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet-js-sdk) installed
- Node.js and npm

### Installation

```bash
git clone <repository-url>
cd Ocean-Carbon-Sequestration---Blue-Carbon
npm install
```

### Running Tests

```bash
npm test
```

## 📖 Contract Functions

### 🌿 Project Management

#### Register Project
```clarity
(register-project project-type location area-hectares)
```
Register a new blue carbon project. Supported types: `"mangrove"`, `"seagrass"`, `"kelp-forest"`

#### Verify Project
```clarity
(verify-project project-id carbon-credits)
```
Verify a project and mint carbon credits (oracle only)

### 🏪 Marketplace

#### Create Sell Order
```clarity
(create-sell-order project-id credits-amount price-per-credit)
```
List carbon credits for sale

#### Buy Credits
```clarity
(buy-credits order-id)
```
Purchase carbon credits from marketplace

#### Cancel Sell Order
```clarity
(cancel-sell-order order-id)
```
Cancel an active sell order

### 💰 Token Operations

#### Transfer Credits
```clarity
(transfer-credits amount recipient)
```
Transfer blue carbon credits to another address

### 👁️ Read-Only Functions

- `get-project`: Get project details
- `get-project-credits`: Get project credit information
- `get-sell-order`: Get marketplace order details
- `get-balance`: Get account's carbon credit balance
- `get-total-supply`: Get total carbon credits minted

## 🔒 Access Control

### Contract Owner
- Authorize/revoke oracles
- Pause/unpause contract

### Authorized Oracles
- Verify projects and mint carbon credits

### Project Owners
- Create marketplace sell orders for their verified credits

## 🌍 Project Types

| Type | Description |
|------|-------------|
| `mangrove` | 🌴 Mangrove forest restoration |
| `seagrass` | 🌾 Seagrass bed conservation |
| `kelp-forest` | 🪸 Kelp forest cultivation |

## 📈 Usage Example

1. **Register Project**: Submit restoration project details
2. **Oracle Verification**: Authorized oracle verifies via satellite data
3. **Credit Minting**: Verified projects receive carbon credit tokens
4. **Marketplace Trading**: Project owners can sell credits to buyers

## ⚠️ Error Codes

- `u100`: Not authorized
- `u101`: Project not found
- `u102`: Insufficient credits
- `u103`: Invalid amount
- `u104`: Project not verified
- `u105`: Oracle not authorized
- `u106`: Invalid project type
- `u107`: Project already exists

## 🛡️ Security

Contract includes:
- Access control for critical functions
- Input validation for all parameters
- Emergency pause functionality
- Oracle authorization system

## 📄 License

MIT License

- 🔥 **Credit Retirement**: Permanently retire credits for verifiable carbon offsetting

## 🔥 Token Retirement

#### Retire Credits
```clarity
(retire-credits amount)
```
Permanently retire carbon credits to offset emissions, burning them from circulation

### 👁️ Read-Only Functions

- `get-project`: Get project details
- `get-project-credits`: Get project credit information
- `get-sell-order`: Get marketplace order details
- `get-balance`: Get account's carbon credit balance
- `get-total-supply`: Get total carbon credits minted
- `get-retired-credits`: Get total retired credits for an account

## 📈 Usage Example

1. **Register Project**: Submit restoration project details
2. **Oracle Verification**: Authorized oracle verifies via satellite data
3. **Credit Minting**: Verified projects receive carbon credit tokens
4. **Marketplace Trading**: Project owners can sell credits to buyers
5. **Credit Retirement**: Users can retire credits to achieve carbon neutrality and demonstrate environmental commitment
