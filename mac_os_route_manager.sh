#!/bin/bash

# MacOs Route Manager

# Set backup directory and use timestamp for backup files
BACKUP_DIR="$HOME/.route_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mkdir -p "$BACKUP_DIR"

# Function to backup current routing table
backup_routes() {
    local backup_file="$BACKUP_DIR/route_backup_$TIMESTAMP.txt"
    echo "Backing up routing table to: $backup_file"
    netstat -nr > "$backup_file"

    # Create a simplified version for restoration
    # This version contains only the necessary fields for the route command
    echo "# Route restoration commands" > "$BACKUP_DIR/restore_$TIMESTAMP.sh"
    echo "#!/bin/bash" >> "$BACKUP_DIR/restore_$TIMESTAMP.sh"

    # On macOS, parse netstat output and create restoration commands
    netstat -nr | grep -v 'Destination' | grep -v '^$' | while read -r dest gateway flags refs use netif expiry; do
        # Skip header lines and localhost routes
        if [[ "$dest" == "Destination" ]] || [[ "$dest" == "127.0.0.1" ]]; then
            continue
        fi
        # Create restoration command
        echo "sudo route add -net $dest $gateway" >> "$BACKUP_DIR/restore_$TIMESTAMP.sh"
    done

    chmod +x "$BACKUP_DIR/restore_$TIMESTAMP.sh"
    echo "Created restoration script: $BACKUP_DIR/restore_$TIMESTAMP.sh"
}

# Function to list available backups
list_backups() {
    echo "Available routing table backups:"
    ls -l "$BACKUP_DIR"/*
}

# Function to restore from backup
restore_routes() {
    if [ "$#" -ne 1 ]; then
        echo "Please specify the backup file to restore from"
        list_backups
        return 1
    fi

    local restore_script="$1"
    if [ ! -f "$restore_script" ]; then
        echo "Backup file not found: $restore_script"
        return 1
    fi

    echo "Warning: This will modify your current routing table."
    read -p "Are you sure you want to continue? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        echo "Restoring routing table..."
        # First, backup current state
        backup_routes

        # Clear all routes (except default)
        echo "Clearing current routes..."
        netstat -nr | grep -v 'default' | grep -v 'Destination' | grep -v '^$' | while read -r dest gateway flags refs use netif expiry; do
            if [[ "$dest" != "Destination" ]] && [[ "$dest" != "127.0.0.1" ]]; then
                sudo route delete "$dest" >/dev/null 2>&1
            fi
        done

        # Execute restoration script
        echo "Applying routes from backup..."
        sudo bash "$restore_script"
        echo "Restoration complete."
    else
        echo "Restoration cancelled."
    fi
}

# Function to display current routing table
show_routes() {
    echo "Current routing table:"
    netstat -nr
}

# Function to add a route
add_route() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: add_route <network> <netmask> <gateway>"
        return 1
    fi

    # Backup before making changes
    backup_routes

    echo "Adding route: network=$1 netmask=$2 gateway=$3"
    sudo route add -net $1 -netmask $2 $3
}

# Function to delete a route
delete_route() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: delete_route <network>"
        return 1
    fi

    # Backup before making changes
    backup_routes

    echo "Deleting route for network: $1"
    sudo route delete $1
}

# Main menu
while true; do
    echo
    echo "macOS Route Management"
    echo "1. Show current routes"
    echo "2. Add a route"
    echo "3. Delete a route"
    echo "4. Backup current routing table"
    echo "5. List available backups"
    echo "6. Restore from backup"
    echo "7. Exit"
    echo
    read -p "Select an option (1-7): " choice

    case $choice in
        1)
            show_routes
            ;;
        2)
            read -p "Enter network (e.g., 192.168.1.0): " network
            read -p "Enter netmask (e.g., 255.255.255.0): " netmask
            read -p "Enter gateway: " gateway
            add_route "$network" "$netmask" "$gateway"
            ;;
        3)
            read -p "Enter network to delete: " network
            delete_route "$network"
            ;;
        4)
            backup_routes
            ;;
        5)
            list_backups
            ;;
        6)
            list_backups
            echo
            read -p "Enter the full path of the restore script to use: " restore_file
            restore_routes "$restore_file"
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please select 1-7."
            ;;
    esac
done