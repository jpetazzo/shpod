/*
 * This was taken from https://github.com/justincormack/addmount
 */

#define _GNU_SOURCE
#include <unistd.h>
#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mount.h>
#include <sys/syscall.h>

#ifndef O_PATH
#define O_PATH 010000000
#endif

int open_tree(int dirfd, const char *pathname, unsigned int flags) {
	return syscall(428, dirfd, pathname, flags);
}

#define OPEN_TREE_CLONE 1
#define AT_RECURSIVE 0x8000

int move_mount(int from_dirfd, const char *from_pathname, int to_dirfd, const char *to_pathname, unsigned int flags) {
	return syscall(429, from_dirfd, from_pathname, to_dirfd, to_pathname, flags);
}

#define MOVE_MOUNT_F_SYMLINKS		0x00000001
#define MOVE_MOUNT_F_AUTOMOUNTS		0x00000002
#define MOVE_MOUNT_F_EMPTY_PATH		0x00000004
#define MOVE_MOUNT_T_SYMLINKS		0x00000010
#define MOVE_MOUNT_T_AUTOMOUNTS		0x00000020
#define MOVE_MOUNT_T_EMPTY_PATH		0x00000040

int main(int argc, char *argv[]) {
	if (argc != 5) {
		printf("Usage %s src_pid src_path dst_pid dst_path\n", argv[0]);
		exit(1);
	}
	const char *spid = argv[1];
	const char *src = argv[2];
	const char *dpid = argv[3];
	const char *dst = argv[4];

	// source mount namespace path
        char smpath[128];
        snprintf(smpath, 128, "/proc/%s/ns/mnt", spid);

	// source mount namespace fd
        int smfd = open(smpath, O_RDONLY);
        if (smfd == -1) {
                perror("open source mount namespace");
                exit(1);
        }

	// destination mlunt namespace path
        char dmpath[128];
        snprintf(dmpath, 128, "/proc/%s/ns/mnt", dpid);

	// destination mount namespace fd
        int dmfd = open(dmpath, O_RDONLY);
        if (dmfd == -1) {
                perror("open destination mount namespace");
                exit(1);
        }

	// enter source mount namespace
        if (setns(smfd, CLONE_NEWNS) == -1) {
                perror("setns source");
                exit(1);
        }
	close(smfd);

	// this creates a file descriptor equavalent to the mount --rbind tree at the source path
	int fd = open_tree(AT_FDCWD, src, OPEN_TREE_CLONE|AT_RECURSIVE);
	if (fd == -1) {
		if (errno == ENOSYS) {
			printf("open_tree ENOSYS: you need kernel 5.2 to run this code, please upgrade\n");
		}
		perror("open_tree");
		exit(1);
	}

	// enter destination mount namespace
	if (setns(dmfd, CLONE_NEWNS) == -1) {
		perror("setns destination");
		exit(1);
	}
	close(dmfd);

	// move the mount tree to the new path
	int e = move_mount(fd, "", AT_FDCWD, dst, MOVE_MOUNT_F_EMPTY_PATH);
	if (e == -1) {
		perror("move_mount");
		exit(1);
	}

	close(fd);

	return 0;
}
