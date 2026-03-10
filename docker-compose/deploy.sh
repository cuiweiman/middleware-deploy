#!/bin/bash

# Docker Compose 一键部署脚本
# 用于管理 本地开发环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

COMPOSE_FILE="docker-compose-base.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# MySQL 配置目录
MYSQL_DATA_DIR="mysql/data"
MYSQL_CONF_DIR="mysql/conf"
MYSQL_LOG_DIR="mysql/logs"
MYSQL_INIT_DIR="mysql/init"

# Redis 配置目录
REDIS_DATA_DIR="redis/data"

# etcd 配置目录
ETCD_DATA_DIR="etcd/data"
ETCD_CONF_DIR="etcd/conf"

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
    
    # 设置目录权限（使用更安全的权限设置）
    echo_cmd "chmod -R 755 \"$REDIS_DATA_DIR\""
    chmod -R 755 "$REDIS_DATA_DIR"
    
    # 尝试设置所有权，但不强制要求sudo
    if command -v sudo >/dev/null 2>&1; then
        echo_cmd "尝试使用sudo设置所有权: sudo chown -R 1001:1001 \"$REDIS_DATA_DIR\""
        if sudo -n chown -R 1001:1001 "$REDIS_DATA_DIR" 2>/dev/null; then
            log_success "Redis 目录权限修复完成（使用sudo）"
        else
            log_warning "无法使用sudo设置所有权，使用普通权限模式"
            log_success "Redis 目录权限设置完成（普通模式）"
        fi
    else
        log_warning "sudo命令不可用，使用普通权限模式"
        log_success "Redis 目录权限设置完成（普通模式）"
    fi
}

# 修复 etcd 权限问题
fix_etcd_permissions() {
    log_info "修复 etcd 挂载目录权限..."
    
    if [ ! -d "$ETCD_DATA_DIR" ]; then
        log_info "创建 etcd 数据目录: $ETCD_DATA_DIR"
        mkdir -p "$ETCD_DATA_DIR"
    fi
    
    if [ ! -d "$ETCD_CONF_DIR" ]; then
        log_info "创建 etcd 配置目录: $ETCD_CONF_DIR"
        mkdir -p "$ETCD_CONF_DIR"
    fi
    
    # 设置目录权限
    echo_cmd "chmod -R 755 \"$ETCD_DATA_DIR\" \"$ETCD_CONF_DIR\""
    chmod -R 755 "$ETCD_DATA_DIR" "$ETCD_CONF_DIR"
    
    log_success "etcd 目录权限修复完成"
}

# 修复所有权限问题
fix_all_permissions() {
    log_info "修复所有服务的挂载目录权限..."
    
    fix_redis_permissions
    fix_etcd_permissions
    
    log_success "所有服务目录权限修复完成"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录结构..."
    
    local dirs=("$MYSQL_DATA_DIR" "$MYSQL_CONF_DIR" "$MYSQL_LOG_DIR" "$MYSQL_INIT_DIR" "$REDIS_DATA_DIR" "$ETCD_DATA_DIR" "$ETCD_CONF_DIR")
    
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
    echo_cmd "chmod 755 \"$MYSQL_DATA_DIR\" \"$REDIS_DATA_DIR\" \"$ETCD_DATA_DIR\" \"$ETCD_CONF_DIR\""
    chmod 755 "$MYSQL_DATA_DIR" "$REDIS_DATA_DIR" "$ETCD_DATA_DIR" "$ETCD_CONF_DIR"
    
    # 修复 Redis 权限
    fix_redis_permissions
    
    # 修复 etcd 权限
    fix_etcd_permissions
    
    log_success "目录结构创建完成"
}

# 创建 MySQL 配置文件
create_mysql_config() {
    log_info "检查 MySQL 配置目录..."
    
    # 确保配置目录存在
    if [ ! -d "$MYSQL_CONF_DIR" ]; then
        log_info "创建 MySQL 配置目录: $MYSQL_CONF_DIR"
        mkdir -p "$MYSQL_CONF_DIR"
    fi
    
    # MySQL 配置现在已整合到 docker-compose-base.yml 文件中
    # 不再需要创建独立的 my.cnf 配置文件
    log_success "MySQL 配置已整合到 Docker Compose 文件中"
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

# 测试 etcd 服务
test_etcd_service() {
    log_info "测试 etcd 服务功能..."
    
    cd "$SCRIPT_DIR"
    
    # 检查 etcd 服务是否运行
    if ! docker-compose -f "$COMPOSE_FILE" ps etcd | grep -q "Up"; then
        log_error "etcd 服务未运行，请先启动服务"
        return 1
    fi
    
    echo -e "\n${BLUE}=== etcd 功能测试 ===${NC}"
    
    # 测试设置键值对
    echo_cmd "设置测试键值对: test_key -> hello_etcd"
    if docker-compose -f "$COMPOSE_FILE" exec etcd etcdctl put test_key "hello_etcd" > /dev/null 2>&1; then
        log_success "✓ 设置键值对成功"
    else
        log_error "✗ 设置键值对失败"
        return 1
    fi
    
    # 测试获取键值对
    echo_cmd "获取测试键值对: test_key"
    VALUE=$(docker-compose -f "$COMPOSE_FILE" exec etcd etcdctl get test_key --print-value-only 2>/dev/null | tr -d '[:space:]')
    if [ "$VALUE" = "hello_etcd" ]; then
        log_success "✓ 获取键值对成功: test_key = $VALUE"
    else
        log_error "✗ 获取键值对失败"
        return 1
    fi
    
    # 测试删除键值对
    echo_cmd "删除测试键值对: test_key"
    if docker-compose -f "$COMPOSE_FILE" exec etcd etcdctl del test_key > /dev/null 2>&1; then
        log_success "✓ 删除键值对成功"
    else
        log_error "✗ 删除键值对失败"
        return 1
    fi
    
    # 测试集群健康状态
    echo_cmd "检查 etcd 集群健康状态"
    if docker-compose -f "$COMPOSE_FILE" exec etcd etcdctl endpoint health > /dev/null 2>&1; then
        log_success "✓ etcd 集群健康状态正常"
    else
        log_error "✗ etcd 集群健康状态异常"
        return 1
    fi
    
    echo -e "\n${GREEN}=== etcd 功能测试全部通过 ===${NC}"
    log_success "etcd 服务功能正常，部署成功！"
    
    echo -e "\n${BLUE}使用说明:${NC}"
    echo "- etcd 服务端口: 2379 (客户端), 2380 (节点间通信)"
    echo "- 数据存储目录: $ETCD_DATA_DIR"
    echo "- 配置文件目录: $ETCD_CONF_DIR"
    echo ""
    echo "${BLUE}常用命令:${NC}"
    echo "启动服务: docker-compose -f $COMPOSE_FILE up -d etcd"
    echo "停止服务: docker-compose -f $COMPOSE_FILE stop etcd"
    echo "查看日志: docker-compose -f $COMPOSE_FILE logs etcd"
    echo "进入容器: docker-compose -f $COMPOSE_FILE exec etcd sh"
    
    return 0
}



# 测试所有服务功能
test_all_services() {
    log_info "测试所有服务功能..."
    
    local all_tests_passed=true
    
    # 测试 etcd
    if ! test_etcd_service; then
        log_error "etcd 服务测试失败"
        all_tests_passed=false
    fi
    

    
    if [ "$all_tests_passed" = true ]; then
        echo -e "\n${GREEN}=== 所有服务功能测试全部通过 ===${NC}"
        log_success "所有服务功能正常，部署成功！"
    else
        echo -e "\n${RED}=== 部分服务测试失败 ===${NC}"
        log_error "请检查失败的服务并重新测试"
        return 1
    fi
    
    return 0
}

# 显示使用帮助
show_help() {
    echo -e "${BLUE}=== Docker Compose 一键部署脚本使用说明 ===${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo -e "${GREEN}=== 服务部署选项 ===${NC}"
    echo "  start            启动所有服务（MySQL、Redis、etcd）"
    echo "  start-mysql      仅部署 MySQL 服务"
    echo "  start-redis      仅部署 Redis 服务"
    echo "  start-etcd       仅部署 etcd 服务"
    echo ""
    echo -e "${GREEN}=== 服务管理选项 ===${NC}"
    echo "  stop             停止所有服务"
    echo "  restart          重启所有服务"
    echo "  status           查看服务状态"
    echo "  logs             查看服务日志"
    echo ""
    echo -e "${GREEN}=== 数据库管理选项 ===${NC}"
    echo "  backup           备份数据库"
    echo "  cleanup          清理旧的备份文件"
    echo ""
    echo -e "${GREEN}=== 权限修复选项 ===${NC}"
    echo "  fix-redis        修复 Redis 权限问题"
    echo "  fix-etcd         修复 etcd 权限问题"
    echo "  fix-all          修复所有服务权限问题"
    echo ""
    echo -e "${GREEN}=== 服务测试选项 ===${NC}"
    echo "  test-etcd        测试 etcd 服务功能"
    echo "  test-all         测试所有服务功能"
    echo ""
    echo -e "${GREEN}=== 其他选项 ===${NC}"
    echo "  menu             显示交互式菜单"
    echo "  help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start           # 启动所有服务"
    echo "  $0 start-mysql     # 仅启动 MySQL"
    echo "  $0 start-redis     # 仅启动 Redis"
    echo "  $0 start-etcd      # 仅启动 etcd"
    echo "  $0 logs            # 查看日志"
    echo "  $0 fix-redis       # 修复 Redis 权限"
    echo "  $0 fix-etcd        # 修复 etcd 权限"
    echo "  $0 fix-all         # 修复所有权限"
    echo "  $0 test-etcd       # 测试 etcd 功能"
    echo "  $0 menu            # 使用交互式菜单"
}

# 交互式菜单
show_menu() {
    while true; do
        echo -e "\n${BLUE}=== Docker Compose 管理菜单 ===${NC}"
        echo -e "${GREEN}=== 选择中间件 ===${NC}"
        echo "1) MySQL 管理"
        echo "2) Redis 管理"
        echo "3) etcd 管理"
        echo "4) 所有服务管理"
        echo ""
        echo -e "${RED}=== 其他选项 ===${NC}"
        echo "5) 退出菜单"
        
        read -p "请选择中间件 [1-5]: " middleware_choice
        
        case $middleware_choice in
            1)
                mysql_menu
                ;;
            2)
                redis_menu
                ;;
            3)
                etcd_menu
                ;;
            4)
                all_services_menu
                ;;
            5)
                log_info "退出菜单"
                break
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按回车键返回主菜单..."
    done
}

# MySQL 管理菜单
mysql_menu() {
    while true; do
        echo -e "\n${BLUE}=== MySQL 管理菜单 ===${NC}"
        echo -e "${GREEN}=== 部署操作 ===${NC}"
        echo "1) 部署 MySQL 服务"
        echo ""
        echo -e "${GREEN}=== 服务管理 ===${NC}"
        echo "2) 停止 MySQL 服务"
        echo "3) 重启 MySQL 服务"
        echo "4) 查看 MySQL 状态"
        echo "5) 查看 MySQL 日志"
        echo ""
        echo -e "${GREEN}=== 数据库管理 ===${NC}"
        echo "6) 备份 MySQL 数据库"
        echo ""
        echo -e "${RED}=== 其他 ===${NC}"
        echo "7) 返回主菜单"
        
        read -p "请选择操作 [1-7]: " mysql_choice
        
        case $mysql_choice in
            1)
                deploy_single_service "mysql"
                ;;
            2)
                stop_single_service "mysql"
                ;;
            3)
                restart_single_service "mysql"
                ;;
            4)
                show_single_service_status "mysql"
                ;;
            5)
                show_single_service_logs "mysql"
                ;;
            6)
                backup_database
                ;;
            7)
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

# Redis 管理菜单
redis_menu() {
    while true; do
        echo -e "\n${BLUE}=== Redis 管理菜单 ===${NC}"
        echo -e "${GREEN}=== 部署操作 ===${NC}"
        echo "1) 部署 Redis 服务"
        echo ""
        echo -e "${GREEN}=== 服务管理 ===${NC}"
        echo "2) 停止 Redis 服务"
        echo "3) 重启 Redis 服务"
        echo "4) 查看 Redis 状态"
        echo "5) 查看 Redis 日志"
        echo ""
        echo -e "${GREEN}=== 权限修复 ===${NC}"
        echo "6) 修复 Redis 权限"
        echo ""
        echo -e "${RED}=== 其他 ===${NC}"
        echo "7) 返回主菜单"
        
        read -p "请选择操作 [1-7]: " redis_choice
        
        case $redis_choice in
            1)
                deploy_single_service "redis"
                ;;
            2)
                stop_single_service "redis"
                ;;
            3)
                restart_single_service "redis"
                ;;
            4)
                show_single_service_status "redis"
                ;;
            5)
                show_single_service_logs "redis"
                ;;
            6)
                fix_redis_permissions
                ;;
            7)
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

# etcd 管理菜单
etcd_menu() {
    while true; do
        echo -e "\n${BLUE}=== etcd 管理菜单 ===${NC}"
        echo -e "${GREEN}=== 部署操作 ===${NC}"
        echo "1) 部署 etcd 服务"
        echo ""
        echo -e "${GREEN}=== 服务管理 ===${NC}"
        echo "2) 停止 etcd 服务"
        echo "3) 重启 etcd 服务"
        echo "4) 查看 etcd 状态"
        echo "5) 查看 etcd 日志"
        echo ""
        echo -e "${GREEN}=== 权限修复 ===${NC}"
        echo "6) 修复 etcd 权限"
        echo "7) 测试 etcd 功能"
        echo ""
        echo -e "${RED}=== 其他 ===${NC}"
        echo "8) 返回主菜单"
        
        read -p "请选择操作 [1-8]: " etcd_choice
        
        case $etcd_choice in
            1)
                deploy_single_service "etcd"
                ;;
            2)
                stop_single_service "etcd"
                ;;
            3)
                restart_single_service "etcd"
                ;;
            4)
                show_single_service_status "etcd"
                ;;
            5)
                show_single_service_logs "etcd"
                ;;
            6)
                fix_etcd_permissions
                ;;
            7)
                test_etcd_service
                ;;
            8)
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







# 所有服务管理菜单
all_services_menu() {
    while true; do
        echo -e "\n${BLUE}=== 所有服务管理菜单 ===${NC}"
        echo -e "${GREEN}=== 部署操作 ===${NC}"
        echo "1) 部署所有服务"
        echo ""
        echo -e "${GREEN}=== 服务管理 ===${NC}"
        echo "2) 停止所有服务"
        echo "3) 重启所有服务"
        echo "4) 查看所有服务状态"
        echo "5) 查看所有服务日志"
        echo ""
        echo -e "${GREEN}=== 数据库管理 ===${NC}"
        echo "6) 备份数据库"
        echo "7) 清理旧备份"
        echo ""
        echo -e "${GREEN}=== 权限修复 ===${NC}"
        echo "8) 修复所有权限"
        echo "9) 测试所有服务功能"
        echo ""
        echo -e "${RED}=== 其他 ===${NC}"
        echo "10) 返回主菜单"
        
        read -p "请选择操作 [1-10]: " all_choice
        
        case $all_choice in
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
                fix_all_permissions
                ;;
            9)
                test_all_services
                ;;
            10)
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

# 部署单个服务
deploy_single_service() {
    local service_name="$1"
    
    log_info "部署单个服务: $service_name"
    
    check_docker_environment
    create_directories
    
    case $service_name in
        mysql)
            create_mysql_config
            ;;
        redis)
            fix_redis_permissions
            ;;
        etcd)
            fix_etcd_permissions
            ;;
    esac
    
    cd "$SCRIPT_DIR"
    
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" up -d $service_name"
    if docker-compose -f "$COMPOSE_FILE" up -d "$service_name"; then
        log_success "$service_name 服务部署成功"
        
        # 显示该服务的状态
        echo -e "\n${BLUE}=== $service_name 服务状态 ===${NC}"
        docker-compose -f "$COMPOSE_FILE" ps "$service_name"
        
        # 如果是etcd，提供测试选项
        if [ "$service_name" = "etcd" ]; then
            echo -e "\n${BLUE}是否测试 etcd 功能？${NC}"
            read -p "输入 y 进行测试，其他键跳过: " test_choice
            if [ "$test_choice" = "y" ] || [ "$test_choice" = "Y" ]; then
                test_etcd_service
            fi
        fi
    else
        log_error "$service_name 服务部署失败"
        exit 1
    fi
}

# 停止单个服务
stop_single_service() {
    local service_name="$1"
    
    log_info "停止 $service_name 服务..."
    
    cd "$SCRIPT_DIR"
    
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" stop $service_name"
    if docker-compose -f "$COMPOSE_FILE" stop "$service_name"; then
        log_success "$service_name 服务停止成功"
    else
        log_error "$service_name 服务停止失败"
        exit 1
    fi
}

# 重启单个服务
restart_single_service() {
    local service_name="$1"
    
    log_info "重启 $service_name 服务..."
    
    cd "$SCRIPT_DIR"
    
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" restart $service_name"
    if docker-compose -f "$COMPOSE_FILE" restart "$service_name"; then
        log_success "$service_name 服务重启成功"
        show_single_service_status "$service_name"
    else
        log_error "$service_name 服务重启失败"
        exit 1
    fi
}

# 查看单个服务状态
show_single_service_status() {
    local service_name="$1"
    
    log_info "查看 $service_name 服务状态..."
    
    cd "$SCRIPT_DIR"
    
    echo -e "\n${BLUE}=== $service_name 服务状态 ===${NC}"
    echo_cmd "docker-compose -f \"$COMPOSE_FILE\" ps $service_name"
    docker-compose -f "$COMPOSE_FILE" ps "$service_name"
    
    echo -e "\n${BLUE}=== $service_name 容器资源使用 ===${NC}"
    echo_cmd "docker stats --no-stream \$(docker-compose -f \"$COMPOSE_FILE\" ps -q $service_name)"
    docker stats --no-stream $(docker-compose -f "$COMPOSE_FILE" ps -q "$service_name")
}

# 查看单个服务日志
show_single_service_logs() {
    local service_name="$1"
    
    log_info "查看 $service_name 服务日志..."
    
    cd "$SCRIPT_DIR"
    
    echo -e "\n${BLUE}=== $service_name 日志选项 ===${NC}"
    echo "1) 查看完整日志"
    echo "2) 实时跟踪日志"
    echo "3) 查看最近100行日志"
    
    read -p "请选择日志查看方式 [1-3]: " log_option
    
    case $log_option in
        1)
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs $service_name"
            docker-compose -f "$COMPOSE_FILE" logs "$service_name"
            ;;
        2)
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs -f $service_name"
            docker-compose -f "$COMPOSE_FILE" logs -f "$service_name"
            ;;
        3)
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs --tail=100 $service_name"
            docker-compose -f "$COMPOSE_FILE" logs --tail=100 "$service_name"
            ;;
        *)
            log_error "无效选择，默认查看完整日志"
            echo_cmd "docker-compose -f \"$COMPOSE_FILE\" logs $service_name"
            docker-compose -f "$COMPOSE_FILE" logs "$service_name"
            ;;
    esac
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
        start-mysql)
            deploy_single_service "mysql"
            ;;
        start-redis)
            deploy_single_service "redis"
            ;;
        start-etcd)
            deploy_single_service "etcd"
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
        fix-etcd)
            fix_etcd_permissions
            ;;

        fix-all)
            fix_all_permissions
            ;;
        test-etcd)
            test_etcd_service
            ;;

        test-all)
            test_all_services
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