import click
import yaml


def add_entry(data, hostname, ip_address):
    if hostname not in data['names']:
        data['names'].append(hostname)
        data['dns_clients'][hostname] = ip_address
        print(f"Added {hostname} with IP address {ip_address}.")
    else:
        print(f"{hostname} already exists in the list of hostnames.")


def remove_entry(data, hostname):
    if hostname in data['names']:
        data['names'].remove(hostname)
        print(f"Removed {hostname}.")
        if hostname in data['dns_clients']:
            del data['dns_clients'][hostname]
            print(f"Removed {hostname}.")
    else:
        print(f"{hostname} not found in the list of hostnames.")


@click.command()
@click.option('--add', nargs=2, metavar=('HOSTNAME', 'IP_ADDRESS'), help='Add a hostname and IP address', default=None)
@click.option('--remove', nargs=1, metavar='HOSTNAME', help='Remove a hostname', default=None)

def main(add, remove):
    # Load data from YAML file
    with open('vars/main.yml', 'r') as f:
        data = yaml.load(f, Loader=yaml.FullLoader)

    if add is not None and len(add) == 2:
        # Add entry from command-line arguments
        add_entry(data, add[0], add[1])
        with open('vars/main.yml', 'w') as f:
            yaml.dump(data, f)
    elif remove is not None:
        # Remove entry from command-line argument
        remove_entry(data, remove)
        with open('vars/main.yml', 'w') as f:
            yaml.dump(data, f)
    else:
        # Fall back to wizard
        while True:
            print("Select an action:")
            print("1. Add hostname and IP address")
            print("2. Remove hostname and IP address")
            print("3. Quit")
            choice = input("Enter choice: ")
            if choice == '1':
                hostname = input("Enter hostname to add: ")
                ip_address = input("Enter IP address for the hostname: ")
                add_entry(data, hostname, ip_address)
                with open('vars/main.yml', 'w') as f:
                    yaml.dump(data, f)
            elif choice == '2':
                hostname = input("Enter hostname to remove: ")
                remove_entry(data, hostname)
                with open('vars/main.yml', 'w') as f:
                    yaml.dump(data, f)
            elif choice == '3':
                with open('vars/main.yml', 'w') as f:
                    yaml.dump(data, f)
                break
            else:
                print("Invalid choice. Try again.")


if __name__ == '__main__':
    main()
