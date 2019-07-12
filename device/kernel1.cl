
//#define DEBUG_ENERGY_KERNEL1

__kernel void __attribute__ ((reqd_work_group_size(NUM_OF_THREADS_PER_BLOCK,1,1)))
gpu_calc_initpop(	
			char   dockpars_num_of_atoms,
			char   dockpars_num_of_atypes,
			int    dockpars_num_of_intraE_contributors,
			char   dockpars_gridsize_x,
			char   dockpars_gridsize_y,
			char   dockpars_gridsize_z,
							    		// g1 = gridsize_x
			uint   dockpars_gridsize_x_times_y, 		// g2 = gridsize_x * gridsize_y
			uint   dockpars_gridsize_x_times_y_times_z,	// g3 = gridsize_x * gridsize_y * gridsize_z
			float  dockpars_grid_spacing,
	 __global const float* restrict dockpars_fgrids, // This is too large to be allocated in __constant 
			int    dockpars_rotbondlist_length,
			float  dockpars_coeff_elec,
			float  dockpars_coeff_desolv,
	 __global const float* restrict dockpars_conformations_current,
	 __global       float* restrict dockpars_energies_current,
	 __global       int*   restrict dockpars_evals_of_new_entities,
			int    dockpars_pop_size,
			float  dockpars_qasp,
			float  dockpars_smooth,

	 __constant     kernelconstant_interintra* 	kerconst_interintra,
	 __global const kernelconstant_intracontrib*  	kerconst_intracontrib,
	 __constant     kernelconstant_intra*		kerconst_intra,
	 __constant     kernelconstant_rotlist*   	kerconst_rotlist,
	 __constant     kernelconstant_conform*		kerconst_conform
){
        // Some OpenCL compilers don't allow declaring 
	// local variables within non-kernel functions.
	// These local variables must be declared in a kernel, 
	// and then passed to non-kernel functions.
	__local float  genotype[ACTUAL_GENOTYPE_LENGTH];
	__local float  energy;
	__local int    run_id;

	__local float calc_coords_x[MAX_NUM_OF_ATOMS];
	__local float calc_coords_y[MAX_NUM_OF_ATOMS];
	__local float calc_coords_z[MAX_NUM_OF_ATOMS];
	__local float partial_energies[NUM_OF_THREADS_PER_BLOCK];
	#if defined (DEBUG_ENERGY_KERNEL)
	__local float partial_interE[NUM_OF_THREADS_PER_BLOCK];
	__local float partial_intraE[NUM_OF_THREADS_PER_BLOCK];
	#endif

	// Copying genotype from global memory
	event_t ev = async_work_group_copy(genotype,
			                   dockpars_conformations_current + GENOTYPE_LENGTH_IN_GLOBMEM*get_group_id(0),
			                   ACTUAL_GENOTYPE_LENGTH, 0);

	// Determining run-ID
	if (get_local_id(0) == 0) {
		run_id = get_group_id(0) / dockpars_pop_size;
	}

	// Asynchronous copy should be finished by here
	wait_group_events(1, &ev);

	// Evaluating initial genotypes
	barrier(CLK_LOCAL_MEM_FENCE);

	// =============================================================
	gpu_calc_energy(dockpars_rotbondlist_length,
			dockpars_num_of_atoms,
			dockpars_gridsize_x,
			dockpars_gridsize_y,
			dockpars_gridsize_z,
							    	// g1 = gridsize_x
			dockpars_gridsize_x_times_y, 		// g2 = gridsize_x * gridsize_y
			dockpars_gridsize_x_times_y_times_z,	// g3 = gridsize_x * gridsize_y * gridsize_z
			dockpars_fgrids,
			dockpars_num_of_atypes,
			dockpars_num_of_intraE_contributors,
			dockpars_grid_spacing,
			dockpars_coeff_elec,
			dockpars_qasp,
			dockpars_coeff_desolv,
			dockpars_smooth,

			genotype,
			&energy,
			&run_id,
			// Some OpenCL compilers don't allow declaring 
			// local variables within non-kernel functions.
			// These local variables must be declared in a kernel, 
			// and then passed to non-kernel functions.
			calc_coords_x,
			calc_coords_y,
			calc_coords_z,
			partial_energies,
			#if defined (DEBUG_ENERGY_KERNEL)
			partial_interE,
			partial_intraE,
			#endif
#if 0
			false,
#endif
		   	kerconst_interintra,
		   	kerconst_intracontrib,
		   	kerconst_intra,
		   	kerconst_rotlist,
		   	kerconst_conform
			);
	// =============================================================

	if (get_local_id(0) == 0) {
		dockpars_energies_current[get_group_id(0)] = energy;
		dockpars_evals_of_new_entities[get_group_id(0)] = 1;

		#if defined (DEBUG_ENERGY_KERNEL1)
		printf("%-18s [%-5s]---{%-5s}   [%-10.8f]---{%-10.8f}\n", "-ENERGY-KERNEL1-", "GRIDS", "INTRA", partial_interE[0], partial_intraE[0]);
		#endif
	}
}
