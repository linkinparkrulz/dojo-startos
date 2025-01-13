# Dojo

## Overview
Dojo is a powerful backend server designed for Ashigaru, Samourai Wallet, Sparrow, and other light wallets. It provides essential services for managing HD accounts, BIP47 addresses, balances, and transaction lists.

## Features
- Database to track transactions
- API endpoints for wallet interactions
- Choose between bitcoin core and testnet4 for node
- Choose between electrs and fulcrum for an indexer
- Handles BIP44, BIP49, and BIP84 address derivation
- Manages HD accounts and BIP47 (PayNym) addresses
- Only backend server that supports wallets that use Ricochet, Stonewall, StonewallX2 and Stowaway

## Dependencies
Dojo requires:
- Bitcoin Core or Testnet4 (>=0.21.1.2)
- Fulcrum or Electrs for address indexing (>=1.11.0 or >=0.10.7)

## Usage

### Initial Setup
1. Install Dojo from the StartOS marketplace
2. All default configs are set in accordance with optimal software performance
3. In the Dojo StartOS app page, click on START
4. Wait for initial sync with Bitcoin Core
5. Wait for initial synce with indexer of choice

### Connecting Wallets
1. Open your supported wallet (Samourai, Sparrow, etc.)
2. On the Dojo StartOS app page there is DEPENDENCIES, HEALTH CHECKS, MENU AND ADDITIONAL INFORMATION
3. Scroll to MENU and click on PROPERTIES
3. In Properties, you will see PAIRING CODE
4. You can click the QR Code symbol to surface a scannable QR or you can click the clipboard to copy the pairing code
5. Follow your wallet's specific connection instructions

### Accessing the Dojo Maintenance Tool (DMT)
1. Dojo is only accessible through a Tor enabled browser
2. On the Dojo StartOS app page, scroll to MENU and click on INTERFACES
3. In INTERFACES, you will see the .onion address of your Dojo under TOR ADDRESS
4. Copy the .onion address and paste it into your Tor enabled browser or scan the QR code
5. The password for your DMT is under the MENU heading as well.
6. Click on PROPERTIES and in there you will see ADMIN KEY
7. The ADMIN KEY can be copied and pasyed into the DMT textbox in your Tor Browser
5. In the Maintenance Tool, you can see the status of your Dojo, your indexer, your node and database
6. There is also the ability to do PUSH TX's and CUSTOM SCANS OF YOUR WALLET
7. You can also see the settings of your Dojo and your indexer

### Maintenance
- Regular backups are automatically handled by StartOS
- Updates will be available through the StartOS marketplace

## Indexer Selection
Dojo supports two indexing options:
1. **Fulcrum**: Faster scanning and indexing, ideal for deep wallets
2. **Electrs**: More stable but slower performance

Choose your indexer in the Dojo configuration settings.

## Troubleshooting

### Common Issues
1. **Connection Issues**
   - Verify Bitcoin Core is fully synced
   - Check your .onion address is correct
   - Ensure your wallet supports Dojo backends

2. **Sync Problems**
   - Allow initial sync to complete
   - Check Bitcoin Core connection
   - Verify indexer status if enabled

### Support
For additional support:
- Visit the [Dojo Start-OS GitHub repository](https://github.com/Start9Labs/dojo-startos)
- Check the StartOS documentation
- Join the StartOS community channels
- Dojo-StartOS is not maintained by the Dojo Open Source Project

## Backup and Recovery
StartOS manages backups of your Dojo data. To restore:
1. Select the backup point in StartOS
2. Follow the restoration process
3. Allow time for reindexing if necessary

## Security Notes
- Keep your .onion address private
- Regularly update through StartOS
- Monitor your logs for unusual activity
- Use strong passwords for wallet connections

## Advanced Configuration
Advanced users can configure:
- Indexer selection
- Node settings
- API access

Access these settings through the Dojo configuration interface in StartOS