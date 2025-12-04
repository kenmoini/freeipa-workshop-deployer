# Dynamic DNS
Dynamic DNS is a Python script for managing DNS entries using YAML files. It provides a command-line interface for adding and removing DNS entries.

[dynamic_dns.py](../2_ansible_config/dynamic_dns.py)
## Installation
* Clone the repository.
* Install the required dependencies with pip install -r requirements.txt.

## Usage
The script provides the following command-line options:

* `--add:` Add a hostname and IP address.
* `--remove:` Remove a hostname.

You can also run the script without any command-line options to start a wizard interface.

## Examples
**Add a hostname and IP address:**

```python
$ python dynamic_dns.py --add myhost 192.168.0.10
```

**Remove a hostname:**
```python 
$ python dynamic_dns.py --remove myhost
```

**Start the wizard interface:**
```python 
$ python dynamic_dns.py
```

**Help**
You can display help information by running the script with the --help option:
```python
$ python dynamic_dns.py --help
```
### License
