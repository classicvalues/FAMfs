/*
 * Copyright (c) 2017-2018, HPE
 *
 * Written by: Oleg Neverovitch, Dmitry Ivanov
 */

#ifndef FAMFS_ERROR_H
#define FAMFS_ERROR_H

#include <stdio.h>
#include <stdlib.h>

#include <rdma/fi_errno.h>


/* TODO: Move me to debug.h */
#define DEBUG_LVL_(verbosity, lvl, fmt, ...) \
do { \
    if ((verbosity) >= (lvl)) \
        printf("famfs: %s:%d: %s: " fmt "\n", \
               __FILE__, __LINE__, __func__, ## __VA_ARGS__); \
} while (0)

#define ERROR(fmt, ...) \
do {								\
	fprintf(stderr, "famfs error: %s:%d: %s: " fmt "\n",	\
		__FILE__, __LINE__, __func__, ## __VA_ARGS__);	\
} while (0)

#define FI_ERROR_LOG(err, msg, ...)       \
    do {                                  \
        int64_t __err = (int64_t)err;     \
        fprintf(stderr, #msg ": %ld - %s\n", ## __VA_ARGS__, __err, fi_strerror(-__err)); \
    } while (0);

#define ON_FI_ERROR(action, msg, ...)       \
    do {                                    \
        int64_t __err;                      \
        if ((__err = (action))) {           \
            fprintf(stderr, #msg ": %ld - %s\n", ## __VA_ARGS__, \
                    __err, fi_strerror(-__err)); \
            exit(1);                        \
        }                                   \
    } while (0);

#define ON_ERROR(action, msg, ...)          \
    do {                                    \
        int __err;                          \
        if ((__err = (action))) {           \
            fprintf(stderr, #msg ": %d - %m\n", ## __VA_ARGS__, __err); \
            exit(1);                        \
        }                                   \
    } while (0);

#define    ASSERT(x)                    \
    do {                                \
        if (!(x))    {                  \
            fprintf(stderr, "ASSERT failed %s:%s(%d) " #x "\n", __FILE__, __FUNCTION__, __LINE__); \
            exit(1);                    \
        }                               \
    } while (0);

#define ON_FI_ERR_RET(action, msg, ...)       \
    do {                                    \
        int64_t __err;                      \
        if ((__err = (action))) {           \
            fprintf(stderr, #msg ": %ld - %s\n", ## __VA_ARGS__, \
                    __err, fi_strerror(-__err)); \
            return -EINVAL;                 \
        }                                   \
    } while (0);

#define err(str, ...) fprintf(stderr, str "\n", ## __VA_ARGS__)
#define ioerr(str, ...) fprintf(stderr, "%s: " str " - %m\n", __FUNCTION__, ## __VA_ARGS__)

#define fi_err(rc, msg, ...)				\
    do {						\
	if (rc < 0) {					\
	    fprintf(stderr, "%s: " msg ": %d - %s\n",	\
		    __FUNCTION__, ## __VA_ARGS__,	\
		    (int)(rc), fi_strerror(-(int)(rc)));\
	} else if (rc > 0) {				\
	    fprintf(stderr, "%s: " msg ": %d - %m\n",	\
		    __FUNCTION__, ## __VA_ARGS__,	\
		    (int)(rc));				\
	}						\
    } while (0);

#endif /* ifndef FAMFS_ERROR_H */

