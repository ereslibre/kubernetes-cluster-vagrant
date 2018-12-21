all: Dockerfile
	@docker build -t kubernetes-build:latest . &> /dev/null

clean:
	-@docker rm -f -v kubernetes-build
	-@docker rmi kubernetes-build:latest
