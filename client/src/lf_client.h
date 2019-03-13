/*
 * Copyright (c) 2017-2018, HPE
 *
 * Written by: Oleg Neverovitch, Dmitry Ivanov
 */

#ifndef LF_CLIENT_H
#define LF_CLIENT_H

#include <stddef.h>

#include "famfs_lf_connect.h"
#include "famfs_stripe.h"
#include "famfs_stats.h"


typedef struct lfs_ctx_ {
	N_PARAMS_t	*lfs_params;	/* LF clients */
	N_STRIPE_t	*fam_stripe;	/* FAM stripe attributes */
	struct famsim_stats *famsim_stats_fi_wr; /* Carbion stats: fi_write */
} LFS_CTX_t;


int lfs_connect(char *cmd, int rank, size_t rank_size, LFS_CTX_t **lfs_ctx_p);
void free_lfc_ctx(LFS_CTX_t **lfs_ctx_p);

#endif /* LF_CLIENT_H */

