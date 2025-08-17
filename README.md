# Catering and Event Food Service System

A comprehensive blockchain-based catering management system built with Clarity smart contracts for the Stacks blockchain. This system enables transparent, secure, and efficient management of catering services for events of all sizes.

## System Overview

The Catering and Event Food Service System consists of five interconnected smart contracts that handle different aspects of the catering business:

### Core Contracts

1. **Catering Contract (`catering-core.clar`)** - Main contract managing catering orders, pricing, and basic operations
2. **Menu Management (`menu-management.clar`)** - Handles menu items, customization options, and dietary accommodations
3. **Logistics Contract (`logistics-delivery.clar`)** - Manages food preparation scheduling and delivery coordination
4. **Feedback Contract (`feedback-quality.clar`)** - Tracks customer feedback, ratings, and quality assurance
5. **Vendor Management (`vendor-management.clar`)** - Coordinates with multiple vendors and suppliers

## Key Features

### 🍽️ Catering Contract Management
- Create and manage catering contracts with transparent pricing
- Handle deposits, payments, and refunds securely
- Support for different event types and sizes
- Automated contract execution and fulfillment tracking

### 📋 Menu Customization
- Comprehensive menu item management with categories
- Dietary restriction and accommodation tracking
- Custom menu creation for specific events
- Ingredient and allergen information management

### 🚚 Logistics and Delivery
- Food preparation timeline management
- Delivery scheduling and route optimization
- Real-time status updates for preparation and delivery
- Coordination between kitchen staff and delivery teams

### ⭐ Quality Assurance
- Customer feedback and rating system
- Quality metrics tracking and reporting
- Issue resolution and complaint management
- Performance analytics for continuous improvement

### 🤝 Vendor Coordination
- Multi-vendor management and coordination
- Supplier relationship tracking
- Inventory management across vendors
- Cost optimization and vendor performance metrics

## Technical Architecture

### Data Types
- **Catering Orders**: Comprehensive order information with pricing and requirements
- **Menu Items**: Detailed menu data with customization options
- **Delivery Schedules**: Time-based logistics coordination
- **Feedback Records**: Customer satisfaction and quality metrics
- **Vendor Profiles**: Supplier information and performance data

### Security Features
- Role-based access control for different user types
- Secure payment handling with escrow functionality
- Data integrity verification for all transactions
- Audit trails for compliance and transparency

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js 18+ for testing
- Stacks wallet for blockchain interaction

### Installation
\`\`\`bash
# Clone the repository
git clone <repository-url>
cd catering-system

# Install dependencies
npm install

# Run tests
npm test

# Deploy contracts (testnet)
clarinet deploy --testnet
\`\`\`

### Usage Examples

#### Creating a Catering Order
```clarity
(contract-call? .catering-core create-order
  u1000000  ;; total-amount in microSTX
  "Wedding Reception for 150 guests"  ;; event-description
  u1640995200  ;; event-timestamp
  u150  ;; guest-count
)
