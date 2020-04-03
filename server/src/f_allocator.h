/*
 * Copyright (c) 2019, HPE
 *
 * Written by: Yann Livis
 */

#ifndef F_ALLOCATOR_H
#define F_ALLOCATOR_H

/* 
 * Start/stop allocators routines
 *
 *  Params
 *  	none		
 *  			
 *  Returns
 *  	0		success
 *  	<>0		error
 */
int f_start_allocator_threads(void);
int f_stop_allocator_threads(void);

/* 
 * Stripe allocation API 
 */
/*
 * Get a set of preallocated stripes.
 *
 *  Params
 *  	lo		FAMfs layout to get stripe for
 *  	match_stripe	Only useful for single stripe requests, otherwise F_STRIPE_INVALID should be passed.
 *  			If provided, will try to find a stripe that uses different devices than the match_stripe.  
 *  	ss		Stripe set object, ss->count should be set by the caller 
 *  			but could be adjusted down if there is not enough stripes.
 *  			Stripes are returned in the ss->stripes[] array
 *  Returns
 *  	>0		success, returns number of stripes allocated (could be less than requested)
 *  	<>0		error
 */
int f_get_stripe(F_LAYOUT_t *lo, f_stripe_t match_stripe, struct f_stripe_set *ss);

/*
 * Release a set of layout stripes.
 *
 *  Params
 *  	lo		FAMfs layout to release stripe to
 *  	ss		Stripe set object, ss->count and ss->stripes[] should be set by the caller
 *  			to contain stripes to be released 
 *  Returns
 *  	0		success
 *  	<>0		error
 */
int f_put_stripe(F_LAYOUT_t *lo, struct f_stripe_set *ss);

/*
 * Commit a set of layout stripes (mark them ALLOCATED). Should be done after a user process fills them with data.
 *
 *  Params
 *  	lo		FAMfs layout to commit stripe in
 *  	ss		Stripe set object, ss->count and ss->stripes[] should be set by the caller
 *  			to contain stripes to be committed 
 *  Returns
 *  	0		success
 *  	<>0		error
 */
int f_commit_stripe(F_LAYOUT_t *lo, struct f_stripe_set *ss);


/* Device extents allocation/release routines */

/*
 * Allocate a free device extent: set pdev allocation bitmap and adjust pdev/pdi counters
 * 
 *  Params
 *  	lp		FAMfs layout partition pointer
 *	ext		extent entry pointer. Device index to allocate from has to be set 
 *			here  by the caller.
 *  Returns
 *	>=0		device extent number
 *	<0		error
 */
int f_alloc_dev_extent(F_LO_PART_t *lp, F_EXTENT_ENTRY_t *ext);

/*
 * Release device extent: clear pdev allocation bitmaps and adjust pdev/pdi counters
 * 
 *  Params
 *  	lp		FAMfs layout partition pointer
 *	ext		extent entry pointer. 
 *
 *  Returns
 *	none
 */
void f_release_dev_extent(F_LO_PART_t *lp, F_EXTENT_ENTRY_t *ext);

#endif
