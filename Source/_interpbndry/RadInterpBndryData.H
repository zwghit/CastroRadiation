#ifndef _RAD_INTERPBNDRYDATA_H_
#define _RAD_INTERPBNDRYDATA_H_

#include <iostream>

#include <BLassert.H>
#include <BoxArray.H>
#include <FArrayBox.H>
#include <Orientation.H>
#include <Mask.H>
#include <BCRec.H>
#include <Geometry.H>
#include <RadBoundCond.H>
#include <RadBndryData.H>


//@Man:
/*@Memo:
        An InterpBndryData object adds to a BndryData object the ability to
	manipulate and set the data stored in the boundary cells.
*/	
/*@Doc:
        The "Interpbndrydata" class is a virtual base class derived from
	BndryData.  It is intended to provide a more physical method for
	filling boundary-related data.  Boundary values in a BndryData object
	are stored in FabSets around each grid in the domain, and the
	InterpBndryData class provides a mechanism for filling these FabSets,
	consistent with AMR-like numerical discretizations.  When asked to
	set it's boundary values, an InterpBndryData object:
	\begin{enumerate}
	\item Fills with physical boundary values if the FAB is on the
	domain boundary ({\it the corresponding values are presumed to be
	stored in the ghost cells of a MultiFab given to the boundary filling
	routine})
	\item Fills on intersection with data from the VALID region of the
	input MultiFab, ensuring that adjacent FABs use consistent data at
	their intersection, and otherwise,
	\item Fills with values interpolated from a coarser FAB that
	bounds the cells that do not meet the above two criteria
	\end{enumerate}
	
        This class does NOT provide a copy constructor or assignment operator.
	
*/

class BndryRegister;

class RadInterpBndryData : public RadBndryData
{
public:
//@ManMemo: Constructor
//@ManDoc: default constructor
    RadInterpBndryData() : RadBndryData() {};
//@ManDoc: constructor for given BoxArray, etc
    RadInterpBndryData(const BoxArray& _grids, int _ncomp, const Geometry& geom);
//@ManDoc: interpret user BCs to those expected by LinOp: takes integer ratio and
// is a wrapper to the IntVect version
    void setBndryConds(const BCRec& phys_bc,
		       const Geometry& geom, int ratio);
//@ManDoc: interpret user BCs to those expected by LinOp: takes IntVect ratio
    virtual void setBndryConds(const BCRec& phys_bc,
			       const Geometry& geom, IntVect& ratio) = 0;
//@ManDoc: set bndry values at coarse level (non interpolation performed)
    void setBndryValues(const MultiFab& mf, int mf_start,
			int bnd_start, int num_comp,
			const BCRec& phys_bc);
//@ManDoc: set bndry values at fine level, performing necessary interpolations
    void setBndryValues(::BndryRegister& crse, int c_start,
			const MultiFab& fine, int f_start,
			int bnd_start, int num_comp, IntVect& ratio, 
			const BCRec& phys_bc);
//@ManDoc: set bndry values to provided value
    void setBndryValues(Real bv);
};


#endif

