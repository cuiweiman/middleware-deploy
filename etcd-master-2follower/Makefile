

up:
	docker-compose -f docker-compose.yml up -d

down:
	docker-compose -f docker-compose.yml down

mems:
	docker exec -it etcd1 etcdctl member list

etcd1:
	docker exec -it etcd1 etcdctl endpoint health