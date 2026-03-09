# middleware-deploy

Middleware deployment using Docker Compose

## Available Services

- MySQL 8.0 with custom configuration

## Docker Compose Management Script

A convenient script `docker-compose-manager.sh` is provided to manage the services:

### Make the script executable
```bash
chmod +x docker-compose-manager.sh
```

### Usage
```bash
./docker-compose-manager.sh <command> [options]
```

### Commands

- `start` - Start all services
- `stop` - Stop all services  
- `restart` - Restart all services
- `status` - Show service status
- `logs [service]` - Show service logs (optional service name)
- `shell <service>` - Enter container shell
- `help` - Show help message

### Examples

```bash
# Start services
./docker-compose-manager.sh start

# Check status
./docker-compose-manager.sh status

# View MySQL logs
./docker-compose-manager.sh logs mysql

# Enter MySQL container
./docker-compose-manager.sh shell mysql
```

## Manual Docker Compose Commands

You can also use docker-compose directly:

```bash
# Start services
cd docker-compose
docker-compose -f docker-compose-mysql.yml up -d

# Stop services
docker-compose -f docker-compose-mysql.yml down

# View logs
docker-compose -f docker-compose-mysql.yml logs
```
