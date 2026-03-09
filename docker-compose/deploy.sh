#!/bin/bash

# Docker Compose 一键部署脚本
# 用于管理 taskey 项目的本地开发环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="taskey-local"
COMPOSE_FILE="docker-compose-local.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# MySQL 配置目录
MYSQL_DATA_DIR="mysql/data"
MYSQL_CONF_DIR="mysql/conf"
MYSQL_LOG_DIR="mysql/logs"
MYSQL_INIT_DIR="mysql/init"

# Redis 配置目录
REDIS_DATA_DIR="redis/data"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示执行的命令
echo_cmd() {
    echo -e "${YELLOW}[CMD]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 $1 未安装，请先安装该命令"
        return 1
    fi
    return 0
}

# 检查 Docker 环境
check_docker_environment() {
    log_info "检查 Docker 环境..."
    
    if ! check_command "docker"; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! check_command "docker-compose"; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 守护进程未运行，请启动 Docker"
        exit 1
    fi
    
    log_success "Docker 环境检查通过"
}

# 修复 Redis 权限问题
fix_redis_permissions() {
    log_info "修复 Redis 挂载目录权限..."
    
    if [ ! -d "$REDIS_DATA_DIR" ]; then
        log_info "创建 Redis 数据目录: $REDIS_DATA_DIR"
        mkdir -p "$REDIS_DATA_DIR"
    fi
    
    # 设置目录权限（允许用户1001读写）
    echo_cmd "sudo chown -R 1001:1001 \"$REDIS_DATA_DIR\""
    if sudo chown -R 1001:1001 "$REDIS_DATA_DIR" 2>/dev/null; then
        echo_cmd "sudo chmod -R 755 \"$REDIS_DATA_DIR\""
        sudo chmod -R 755 "$REDIS_DATA_DIR"
        log_success "Redis 目录权限修复完成"
    else
        log_warning "无法使用sudo设置权限，尝试普通权限设置"
        echo_cmd "chmod -R 755 \"$REDIS_DATA_DIR\""
        chmod -R 755 "$REDIS_DATA_DIR"
        log_success "Redis 目录权限设置完成（普通模式）"
    fi
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录结构..."
    
    local dirs=("$MYSQL_DATA_DIR" "$MYSQL_CONF_DIR" "$MYSQL_LOG_DIR" "$MYSQL_INIT_DIR" "$REDIS_DATA_DIR")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo_cmd "mkdir -p \"$dir\""
            mkdir -p "$dir"
            log_info "创建目录: $dir"
        else
            log_info "目录已存在: $dir"
        fi
    done
    
    # 设置目录权限
    echo_cmd "chmod 755 \"$MYSQL_DATA_DIR\" \"$REDIS_DATA_DIR\""
    chmod 755 "$MYSQL_DATA_DIR" "$REDIS_DATA_DIR"
    
    # 修复 Redis 权限
    fix_redis_permissions
    
    log_success "目录结构创建完成"
}

# 创建 MySQL 配置文件
create_mysql_config() {
    log_info "创建 MySQL 配置文件..."
    
    local mysql_conf_file="$MYSQL_CONF_DIR/my.cnf"
    
    if [ ! -f "$mysql_conf_file" ]; then
        echo_cmd "cat > \"$mysql_conf_file\" << 'EOF'"
        cat > "$mysql_conf_file" << 'EOF'
[mysqld]
# 基础配置
user = mysql
port = 3306
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
max_connections = 1000
default-time-zone = '+08:00'

# 文件路径
datadir = /var/lib/mysql
socket = /var/run/mysqld/mysqld.sock
pid-file = /var/run/mysqld/mysqld.pid
log-error = /var/log/mysql/error.log

# 内存优化
innodb_buffer_pool_size = 256M
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT

# 二进制日志
server-id = 1
log-bin = mysql-bin
binlog_format = row
expire_logs_days = 7
max_binlog_size = 100M

# 慢查询日志
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2

[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
EOF
        log_success "MySQL 配置文件创建完成: $mysql_conf_file"
    else
        log_info "MySQL 配置文件已存在: $mysql_conf_file"
    fi
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    cd "$SCRIPT_DIR"
    
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" up -d"
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        log_success "服务启动成功"
        show_services_status
    else
        log_error "服务启动失败"
        exit 1
    fi
}

# 停止服务
stop_services() {
    log_info "停止服务..."
    
    cd "$SCRIPT_DIR"
    
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" down"
    if docker-compose -f "$COMPOSE_FILE" down; then
        log_success "服务停止成功"
    else
        log_error "服务停止失败"
        exit 1
    fi
}

# 重启服务
restart_services() {
    log_info "重启服务..."
    
    cd "$SCRIPT_DIR"
    
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" restart"
    if docker-compose -f "$COMPOSE_FILE" restart; then
        log_success "服务重启成功"
        show_services_status
    else
        log_error "服务重启失败"
        exit 1
    fi
}

# 查看服务状态
show_services_status() {
    log_info "查看服务状态..."
    
    cd "$SCRIPT_DIR"
    
    echo -e "\n${BLUE}=== 服务状态 ===${NC}"
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" ps"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo -e "\n${BLUE}=== 容器资源使用 ===${NC}"
    echo_cmd "docker stats --no-stream \$(docker-compose -f \"$COMPOSE_FILE\" ps -q)"
    docker stats --no-stream $(docker-compose -f "$COMPOSE_FILE" ps -q)
}

# 查看服务日志
show_services_logs() {
    log_info "查看服务日志..."
    
    cd "$SCRIPT_DIR"
    
    echo -e "\n${BLUE}选择要查看的日志：${NC}"
    echo "1) 查看所有服务日志"
    echo "2) 查看 MySQL 日志"
    echo "3) 查看 Redis 日志"
    echo "4) 实时跟踪所有日志"
    
    read -p "请选择 [1-4]: " log_choice
    
    case $log_choice in
        1)
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs"
            docker-compose -f "$COMPOSE_FILE" logs
            ;;
        2)
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs mysql"
            docker-compose -f "$COMPOSE_FILE" logs mysql
            ;;
        3)
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs redis"
            docker-compose -f "$COMPOSE_FILE" logs redis
            ;;
        4)
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs -f"
            docker-compose -f "$COMPOSE_FILE" logs -f
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# 备份数据库
backup_database() {
    log_info "备份数据库..."
    
    cd "$SCRIPT_DIR"
    
    local backup_dir="$SCRIPT_DIR/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/backup_$timestamp.sql"
    
    echo_cmd "mkdir -p \"$backup_dir\""
    mkdir -p "$backup_dir"
    
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" exec -T mysql mysqldump -u root -pzacharycui@123 --all-databases > \"$backup_file\""
    if docker-compose -f "$COMPOSE_FILE" exec -T mysql mysqldump -u root -pzacharycui@123 --all-databases > "$backup_file"; then
        log_success "数据库备份成功: $backup_file"
        
        # 压缩备份文件
        echo_cmd "gzip \"$backup_file\""
        gzip "$backup_file"
        log_info "备份文件已压缩: ${backup_file}.gz"
    else
        log_error "数据库备份失败"
        exit 1
    fi
}

# 清理旧的备份文件
cleanup_old_backups() {
    log_info "清理旧的备份文件..."
    
    local backup_dir="$SCRIPT_DIR/backups"
    
    if [ -d "$backup_dir" ]; then
        # 保留最近7天的备份
        echo_cmd "find \"$backup_dir\" -name \"backup_*.sql.gz\" -mtime +7 -delete"
        find "$backup_dir" -name "backup_*.sql.gz" -mtime +7 -delete
        log_success "旧的备份文件清理完成"
    fi
}

# 显示使用帮助
show_help() {
    echo -e "${BLUE}=== Docker Compose 一键部署脚本使用说明 ===${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  start       启动所有服务"
    echo "  stop        停止所有服务"
    echo "  restart     重启所有服务"
    echo "  status      查看服务状态"
    echo "  logs        查看服务日志"
    echo "  backup      备份数据库"
    echo "  cleanup     清理旧的备份文件"
    echo "  fix-redis   修复Redis权限问题"
    echo "  clean-redis 清理Redis数据（解决HSETEX问题）"
    echo "  menu        显示交互式菜单"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start     # 启动服务"
    echo "  $0 logs      # 查看日志"
    echo "  $0 fix-redis # 修复Redis权限"
    echo "  $0 clean-redis # 清理Redis数据"
    echo "  $0 menu      # 使用交互式菜单"
}

# 交互式菜单
show_menu() {
    while true; do
        echo -e "\n${BLUE}=== Docker Compose 管理菜单 ===${NC}"
        echo "1) 启动服务"
        echo "2) 停止服务"
        echo "3) 重启服务"
        echo "4) 查看状态"
        echo "5) 查看日志"
        echo "6) 备份数据库"
        echo "7) 清理旧备份"
        echo "8) 修复Redis权限"
        echo "9) 退出"
        
        read -p "请选择 [1-9]: " choice
        
        case $choice in
            1)
                check_docker_environment
                create_directories
                create_mysql_config
                start_services
                ;;
            2)
                stop_services
                ;;
            3)
                restart_services
                ;;
            4)
                show_services_status
                ;;
            5)
                show_services_logs
                ;;
            6)
                backup_database
                ;;
            7)
                cleanup_old_backups
                ;;
            8)
                fix_redis_permissions
                ;;
            9)
                log_info "退出菜单"
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 主函数
main() {
    local command="${1:-menu}"
    
    case $command in
        start)
            check_docker_environment
            create_directories
            create_mysql_config
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_services_status
            ;;
        logs)
            show_services_logs
            ;;
        backup)
            backup_database
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        fix-redis)
            fix_redis_permissions
            ;;
        menu)
            show_menu
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi