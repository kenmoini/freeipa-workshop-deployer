import click
import yaml
from jinja2 import Template
import os

@click.group()
def cli():
    pass

@cli.command()
@click.argument('os_name')
@click.argument('template_path', type=click.Path(exists=True))
@click.option('--vars-file', '-v', help='Path to YAML vars file', type=click.Path(exists=True))
@click.option('--image', help='Image name', required=False)
@click.option('--rhnregister', help='Enable RHN registration', type=bool, default=False)
@click.option('--rhnorg', help='RHN organization', default='')
@click.option('--rhnactivationkey', help='RHN activation key', default='')
@click.option('--numcpus', help='Number of CPUs', type=int, default=2)
@click.option('--memory', help='Memory size in MB', type=int, default=4096)
@click.option('--disk-size', help='Disk size in GB', type=int, default=20)
@click.option('--reservedns', help='Reserve DNS name', type=bool, default=False)
@click.option('--net-name', help='Network name', default='qubinet')
@click.option('--user', help='User name', required=False)
@click.option('--user-password', help='User password', required=False)
@click.option('--offline-token', help='Offline token', default='')
@click.option('--pull-secret', help='Pull Secret', default='')
@click.option('--help', '-h', is_flag=True, help='Display help message')
def update_yaml(os_name, template_path, vars_file, image, rhnregister, rhnorg, rhnactivationkey, numcpus, memory, disk_size,
                reservedns, net_name, user, user_password, offline_token, pull_secret,help):
    if help:
        click.echo(click.get_current_context().get_help())
        return

    with open(template_path, 'r') as f:
        template_data = f.read()

    template = Template(template_data)

    if vars_file:
        with open(vars_file, 'r') as f:
            vars_data = yaml.safe_load(f) or {}
    else:
        vars_data = {}

    data = yaml.load(template.render(
        **vars_data  # unpack vars_data as keyword arguments
    ), Loader=yaml.SafeLoader)

    if not os.path.isfile('kcli-profiles.yml'):
        with open('kcli-profiles.yml', 'w') as f:
            f.write('')

    with open('kcli-profiles.yml', 'r') as f:
        existing_data = yaml.safe_load(f) or {}

    existing_data[os_name] = data

    with open('kcli-profiles.yml', 'w') as f:
        yaml.dump(existing_data, f)

    print(f'Successfully updated {os_name} entry in kcli-profiles.yml')

if __name__ == '__main__':
    cli()  # call the click CLI function