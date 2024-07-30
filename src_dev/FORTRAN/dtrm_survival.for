      PROGRAM DTRM_V3MAC
C
C  FORTRAN PROGRAM FOR TIME-AREA COMPUTATIONS
C  USES A FLOW-PATH TIME ACCUMULATION METHOD COMPUTED FROM
C  AN ELEVATION DISTRIBUTION ON A RECTANGULAR GRID
C  
C  FLOW SPEEDS ARE BY A MODIFIED MANNING'S EQUATION
C   V = (1.5/N)*R**(2/3)*S**(1/2)
C
C   V3A:  N AND R ARE FIXED VALUES IN THIS VERSION
C 
C 
C BY T.G. CLEVELAND 1-27-93
C
CTGC - TEST COMPILE FOR TXDOT APPLICATION - TEST #1 RECOMPILE 10 YEARS AFTER
C
C NOTE: THIS PROGRAM ASSUMES THE HEAD ARRAY IS ORIENTED SO THAT Y 
C       INCREASES DOWNWARD, X INCREASES RIGHTWARD
C
C     XP(),YP()    ARE X AND Y COORDINATES OF PARTICLES
C     XG(),YG()    ARE X AND Y COORDINATES OF GRID
C     HEAD()       IS HEAD DISTRIBUTION DEFINED ON THE GRID
C     VX()         IS COMPUTED VELOCITY IN DIRECTION OF FLOW
C     VY()         IS COMPUTED TIME OF TRAVEL TO NEXT CELL IN DIRECTION OF FLOW
C     DMAP()       IS FLOW DIRECTION ARRAY IN 8-DIRECTIONS; 
C                    DIRECTION 0 IS OUTLET
C                    DIRECTION 9 IS A PIT
C                    DIRECTION -1 IS NO-FLOW CELL
C                    ENTIRE MODEL IS SURROUNDED BY DIRECTION 0 CELLS, THESE ARE IGNORED
C
C                   
C     DELATX       IS GRID SPACING
C     DELTAT       IS TIME INCREMENT
C     NP           ARE NUMBER OF PARTICLES
C
C     Y - COORDINATE OF GRID IS ASSOCIATED WITH THE "ROW" INDEX
C     X - COORDINATE OF GRID IS ASSOCIATED WITH THE "COLUMN" INDEX
C
C     Y - INCREASES DOWNWARD
C     X - INCREASES RIGHTWARD
C
C     THE UPPER LEFT HAND CORNER OF THE HEAD ARRAY IS X=0,Y=0
C     THE LOWER RIGHT HAND CORNER OF THE HEAD ARRAY IS X=XMAX,Y=YMAX
C
      PARAMETER(NRMAX=1500,NCMAX=1500,NPMAX=2250000,NTMAX=60000)
C
C DECLARE ARRAYS
C
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION XP(NPMAX),YP(NPMAX),TP(NPMAX),WP(NPMAX)
      DIMENSION XPS(NPMAX),YPS(NPMAX)
      DIMENSION VX(NRMAX,NCMAX),VY(NRMAX,NCMAX)
      DIMENSION XG(NCMAX),YG(NRMAX)
      DIMENSION DMAP(NRMAX,NCMAX)
      DIMENSION HEAD(NRMAX,NCMAX)
      DIMENSION PMAP(NRMAX,NCMAX)
c
c 10-04-05  disable debugging statements for smaller output files
c 09-30-05  rebuild code to mimic bejesus implementation -- lost source
c 07-02-04  fix out-of-bounds particle problem for better mass balance.
c 07-06-04  amend fix, try to handle particles as they leave domain.
c 01-25-05  modify grid generation code to cell centers.  initial particle maps fixed.
c 01-25-05  v2a -- remove NON-UNIX code segments for programmer clarity.
c 01-25-05  modify velocity computation to force downhill moves. 
c           use simplified 8-point slope (pour point) model.
c 02-01-05  build velocity model 
c 08-23-09  modify for MacOSX operation
c 08-23-09  modify for different file read order
c 09-24-17  modify for Herrmann survival model
c
      DIMENSION XBG(NCMAX),YBG(NRMAX)
      DIMENSION PBMAP(NRMAX,NCMAX)
      DIMENSION RTIME(NTMAX)
      DIMENSION RMOV(NPMAX)
      CHARACTER*24 DIRECTIVE
c
c clear all data arrays before processing
c
        CALL CARRAY2D(HEAD ,NRMAX,NCMAX,NRMAX,NCMAX)
        CALL CARRAY2D(VX   ,NRMAX,NCMAX,NRMAX,NCMAX)
        CALL CARRAY2D(VY   ,NRMAX,NCMAX,NRMAX,NCMAX)
        CALL CARRAY2D(DMAP ,NRMAX,NCMAX,NRMAX,NCMAX)
        CALL CARRAY2D(PMAP ,NRMAX,NCMAX,NRMAX,NCMAX)
        CALL CARRAY2D(PBMAP,NRMAX,NCMAX,NRMAX,NCMAX)
        temp=valmax2d(head,nrmax,ncmax,nrmax,ncmax)
        write(*,*)'max. elev ',temp
        temp=valmin2d(head,nrmax,ncmax,nrmax,ncmax)
        write(*,*)'min elev ',temp
C
C READ IN HEAD ARRAY FROM HEAD.MAP IN FOLLOWING FORM:
C  FIRST RECORD(ROW)  NUMBER OF ROWS,  NUMBER OF COLUMNS
C  SECOND-NROWS(ROW)  HEAD(I,J),HEAD(I,J+1), ... ,HEAD(I,J+NCOLS)
C  NROW+1 (ROW)       CMANNING,FDEPTH,RMAN
C  NROW+2 (ROW)       DELTAX,TIME STEP,TOTAL TIME
C  NROW+3 (R0W)       NP
C  NROW+4-NROW+4+NP   XP(1),YP(1)
C   ...               XP(NP),YP(NP)
C
      READ(*,'(A)')DIRECTIVE
C—disable read BDF      READ(*,*)BDF
C
      READ(*,*)NROWS,NCOLS
CC      WRITE(*,*)NROWS,NCOLS
C
      DO 100 IROW=1,NROWS
         READ(*,*)(HEAD(IROW,JCOL),JCOL=1,NCOLS)
CC         write(*,*)' read row OK: ',IROW
CC         write(*,*)(HEAD(IROW,JCOL),JCOL=1,NCOLS)
 100  CONTINUE
      temp=valmax2d(head,nrmax,ncmax,nrmax,ncmax)
      write(*,*)'max. elev. after read ',temp
      temp=valmin2d(head,nrmax,ncmax,nrmax,ncmax)
      write(*,*)'min elev after read ',temp
      READ(*,*)CMANNING,FDEPTH,RMAN,ALIFE
      READ(*,*)DELTAX,DELTAT,TIMEMAX,WALL
      READ(*,*)NP,NPRT
C
C MODIFY RMAN USING BDF2RMAN CONVERSION
C 
C-disable BDF -> RMAN overwrite      RMAN=BDF2RMAN(BDF)
C
C MODIFY TO READ A PARTICLE MAP THEN GENERATE PARTICLES
C
      DO 101 IROW=1,NROWS
         READ(*,*)(PMAP(IROW,JCOL),JCOL=1,NCOLS)
 101  CONTINUE
C
C COPY PMAP CONTENT INTO BOUNDARY MAP; USED FOR SLOPE AND VELOCITY COMPUTATIONS
C
      DO 110 IROW=1,NROWS
	DO 111 JCOL=1,NCOLS
	 PBMAP(IROW,JCOL)=PMAP(IROW,JCOL)
 111  CONTINUE
 110  CONTINUE
C
      READ(*,*)NROUT,NCOUT
C	
      WRITE(*,*)'DATA READ COMPLETE -- CLOSING INPUT FILE'
      WRITE(*,*)'INPUT DATA FROM :'
      WRITE(*,*)'HEAD.MAP'
      WRITE(*,*)' ROWS = ',NROWS,' COLUMNS = ',NCOLS
C
	IF(DIRECTIVE .EQ. 'VERBOSE_1' .OR.
     1   DIRECTIVE .EQ. 'VERBOSE_2'     )THEN
       CALL PARRAY2D(HEAD,NRMAX,NCMAX,NROWS,NCOLS)
	END IF
C
      WRITE(*,*)'CMANNING = ',CMANNING
      WRITE(*,*)'FDEPTH       = ',FDEPTH
      WRITE(*,*)'RMAN      = ',RMAN
      WRITE(*,*)'SPACING        = ',DELTAX
C-not using BDF this version      WRITE(*,*)'BDF      =',BDF
      WRITE(*,*)'ALIFE    = ',ALIFE
C
C BUILD GRID LOCATION ARRAYS
C
      CALL BUILDGRID(XG,YG,NRMAX,NCMAX,NROWS,NCOLS,DELTAX)
      CALL BUILDGRID(XBG,YBG,NRMAX,NCMAX,NROWS,NCOLS,DELTAX)
C
C LOCATE THE OUTLET
C
        XOUT=XG(NCOUT)
        YOUT=YG(NROUT)
        XMIN=XG(1)
        XMAX=XG(NCOLS)+DELTAX
        YMIN=YG(1)
        YMAX=YG(NROWS)+DELTAX
        WRITE(*,*)'XMIN = ',XMIN,' XMAX = ',XMAX
        WRITE(*,*)'YMIN = ',YMIN,' YMAX = ',YMAX
        WRITE(*,*)'OUTLET AT (X,Y) = ',XOUT,YOUT
C
C CONVERT THE PARTICLE MAP INTO A PARTICLE ATTRIBUTE ARRAY
C
      NP=0
	IP=0
	LOX=0
	LOY=0
      DO 991 IROW=1,NROWS
	DO 992 JCOL=1,NCOLS
C
	 IF(PMAP(IROW,JCOL) .GT. 0.0)THEN
	  NP=NP+1
	  IP=IP+1 
	  XP(IP)=XG(JCOL)
	  YP(IP)=YG(IROW)
	  TP(IP)=0.D0
C add starting locations for backtrace
      XPS(IP)=XP(IP)
      YPS(IP)=YP(IP)
C add alive/dead attribute
      WP(IP)=1.D0
	 ELSE
	  XBG(JCOL)=-1.D99
	  YBG(IROW)=-1.D99
       END IF
C LOCATE OUTLET
      IF( (XG(JCOL).EQ.XOUT) .AND. (YG(IROW).EQ.YOUT) )THEN
	 LOX = JCOL
	 LOY = IROW
      END IF
 992  CONTINUE
 991  CONTINUE
      WRITE(*,*)'OUTLET AT COL,ROW = ',LOX,LOY
      WRITE(*,*)'NUM. PARTICLES = ',NP
	WRITE(*,*)'PRINT INCREMENT= ',NPRT
C
C COMPUTE VELOCITY DISTRIBUTION
C
      CALL GETVELOCITY(HEAD,VX,VY,NRMAX,NCMAX,NROWS,NCOLS,
     1           CONVEYANCE,CMANNING,RMAN,DELTAX,
     2           FDEPTH,PBMAP,DMAP,LOX,LOY,XG,YG)  
CDEBUG	WRITE(*,*)'PARTICLE MAP AS READ FROM INPUT'
CDEBUG      CALL PARRAY2D(PMAP,NRMAX,NCMAX,NROWS,NCOLS)
	ETIME=0.D0
	RTIME(1)=ETIME
C
C WRITE INITIAL PARTICLE POSITIONS IF VERBOSE_1 OR VERBOSE_2
C
	IF(DIRECTIVE .EQ. 'VERBOSE_1' .OR.
     1   DIRECTIVE .EQ. 'VERBOSE_2'     )THEN

	WRITE(*,*)'PARTICLE MAP AS READ FROM INPUT'
      CALL PARRAY2D(PMAP,NRMAX,NCMAX,NROWS,NCOLS)
	WRITE(*,*)'BOUNDARY MAP AS READ FROM INPUT'
	CALL PARRAY2D(PBMAP,NRMAX,NCMAX,NROWS,NCOLS)
	WRITE(*,*)'GRID COORDINATE VALUES -- XGRID'
	CALL PARRAY1D(XG,NCMAX,NCOLS)
	WRITE(*,*)'GRID COORDINATE VALUES -- YGRID'
	CALL PARRAY1D(YG,NRMAX,NROWS)

      WRITE(*,*)'INITIAL PARTICLE POSITIONS'
      DO 509 IP=1,NP
      CALL FINDPART(XP,YP,XG,YG,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,IP,LPX,LPY)
      WRITE(*,1005)ETIME,XP(IP),YP(IP),VX(LPY,LPX),VY(LPY,LPX),LPY,LPX
 509  CONTINUE
      CALL MAPPART(XP,YP,XG,YG,PMAP,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,NP)
      WRITE(*,*)'PARTICLE MAP AT ELAPSED TIME = ',ETIME
      CALL PARRAY2D(PMAP,NRMAX,NCMAX,NROWS,NCOLS)

	WRITE(*,*)'DIRECTION MAP AT ELAPSED TIME = ',ETIME
      CALL PARRAY2D(DMAP,NRMAX,NCMAX,NROWS,NCOLS)


	END IF
      
      WRITE(*,*)'VELOCITY MAPS BUILT'
      WRITE(*,*)'PARTICLE MAPS BUILT'
      WRITE(*,*)'BEGIN PARTICLE TRACKING'
      WRITE(*,*)'PARTICLE COUNT = ',NP
      write(*,*)'MAX. ELEVATION = ',
     1           valmax2d(head,nrmax,ncmax,nrows,ncols)
      write(*,*)'MIN. ELEVATION = ',
     1           valmin2d(head,nrmax,ncmax,nrows,ncols)
      write(*,*)'outlet elevation = ',
     1           head(loy,lox)
      write(*,*)'maximum velocity = '
     1          ,valmax2d(vx,nrmax,ncmax,nrows,ncols)
      write(*,*)'maximum time     = '
     1          ,valmax2d(vy,nrmax,ncmax,nrows,ncols)
      write(*,*)'minimum velocity = '
     1          ,valmin2d(vx,nrmax,ncmax,nrows,ncols)
      write(*,*)'minimum time     = '
     1          ,valmin2d(vy,nrmax,ncmax,nrows,ncols)
C
C Count alive particles
C
      ALIVE = 0.D0
      DO 666 ILIVE = 1, NP
       ALIVE = ALIVE + WP(IP)
 666  CONTINUE
      WRITE(*,*)'ALIVE COUNT = ',ALIVE
C
C MOVE ALL CURRENT PARTICLES
C
      NPMV=0
      DO 7001 IP=1,NP
      NPMV=NPMV+1
	DO 7002 IM=1,NROWS+NCOLS
C
C MOVE CURRENT PARTICLE UNTIL IT EXITS THE SYSTEM
C
       CALL MOVEPART(XP,YP,XG,YG,VX,VY,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,IP,DELTAT,DELTAX,
     2                    HEAD,CMANNING,DMAP,TP,LOX,LOY)
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C
C PARTICLE DEATH THIS STEP
C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
      IF(WP(IP) .GT. 0.D0) THEN
      RMOV(IP) = RMOV(IP) + 1.0D0
CDEBUG          WRITE(*,*)RMOV(IP),'VALUE OF RMOV'
C PARTICLE IS STILL ALIVE -- SEE IF IT DIES THIS TIME
C INPUT FILE          ALIFE = 0.9D0
      DEATH = RAND()
      IF(DEATH .LE. ALIFE) THEN
            WP(IP)=WP(IP)
         ELSE
            WP(IP)=0.D0
         END IF
      ELSE
         CONTINUE
      END IF
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC




C
C TEST IF PARTICLE IS IN EXIT CELL
C
       CALL FINDPART(XP,YP,XG,YG,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,IP,LPX,LPY)
       IF(LPX .EQ. LOX .AND. LPY .EQ. LOY)THEN
C BRANCH TO NEXT PARTICLE (SEE BELOW)
        GOTO 7001
	 ELSE
	 END IF
C PROGRESS REPORT (USEFUL FOR DEBUGGING)
cDEBUG	IF(NPMV .GE. 100)THEN
cDEBUG	 WRITE(*,*)'MOVED PARTICLE NUM: ',IP
cDEBUG	 NPMV=0
cDEBUG      END IF

 7002 CONTINUE
C
C NEXT PARTICLE
C
 7001 CONTINUE
 
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C WRITE PARTICLE ATTRIBUTES -- USED FOR PLOTTING
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
      OPEN(UNIT=11,FILE='PARTICLE-POSITIONS.TXT')
      WRITE(11,*)'XPS YPS XP YP TP ALIVE'
      DO 8001 IP=1,NP
         WRITE(11,1004)XPS(IP),YPS(IP),XP(IP),YP(IP),TP(IP),WP(IP)
 8001 CONTINUE
      CLOSE(11)
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

C
C SORT THE TIME ARRAY
C
      CALL SORT(NP,TP)
C
C COMPUTE INCREMENT TO WRITE DISTRIBUTION
C
c      NPRT=NP/1000
c	IF(NPRT .LE. 0)THEN
c	 NPRT=1
c	END IF
C
C WRITE THE CUMULATIVE ARRIVAL TIME DISTRIBUTION 
C
      WRITE(*,*)' CUMULATIVE ARRIVAL TIME DISTRIBUTION     '
      WRITE(*,*)'TIME:FRACTION:NUMBER:MASS:MOVE'
      DO 8002 IP=1,NP,NPRT
C2345678901234567890123456789012345678901234567890123456789012345678901234567890
       WRITE(*,1004)TP(IP)/60.0D0,FLOAT(IP)/FLOAT(NP),FLOAT(IP)
     1      ,WP(IP),RMOV(IP)
 8002 CONTINUE
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C COMPUTE HOW MANY STILL ALIVE
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
       ALIVE = 0.D0
      DO 667 ILIVE = 1, NP
        ALIVE = ALIVE + WP(ILIVE)
  667 CONTINUE
      WRITE(*,*)'ALIVE COUNT = ',ALIVE
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C
C CLOSE FILES
C
 9999 CLOSE(11)
      STOP
 1001 FORMAT(1X,21(F7.3,1X))

 1002 FORMAT(1X,F12.3,1X,10(F12.3,1X))
 1003 FORMAT(1X,F12.3,1X,F12.3)
 1004 FORMAT(1X,6(G12.5,1X))
 1005 FORMAT(1X,F12.3,1X,4(F12.3,1X),2(I3,1X))
      END
C**********************************************************************
      SUBROUTINE GETVELOCITY(HEAD,VX,VY,NRMAX,NCMAX,NROWS,NCOLS,
     1           CONVEYANCE,CMANNING,RMAN,DELTAX,
     2           FDEPTH,PBMAP,DMAP,LOX,LOY,XG,YG)  
c
c 2005-0208 version 3
c direction by 8-cell pour-point model
c vx is velocity in downhill direction in ft/sec
c vy is cell-to-cell travel time in seconds
C
C SUBROUTINE TO COMPUTE VELOCITY FIELD FROM ELEVATION MAP 
C DECLARE ARRAYS
C
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION VX(NRMAX,NCMAX),VY(NRMAX,NCMAX)
	DIMENSION XG(NCMAX),YG(NRMAX)
      DIMENSION HEAD(NRMAX,NCMAX)
	DIMENSION PBMAP(NRMAX,NCMAX)
	DIMENSION DMAP(NRMAX,NCMAX)
      DIMENSION D(8)

C 
C COMPUTE SOME CONSTANTS
C
C
C XY DISTANCES ARE IN METERS
C  Z DISTANCES ARE IN FEET
C
      DXINV=1.D0/(DELTAX*3.25)
      CONVEYANCE=(CMANNING/RMAN)*FDEPTH**(2./3.)
c
c selection of FDEPTH multiplier is trial-and-error
c
      CHANNEL=(CMANNING/RMAN)*(2.0*FDEPTH)**(2./3.)
      DSQRTIV=1.D0/SQRT(2.0D0)
C
C COMPUTE VELOCITY POTENTIAL FIELD
C
C -- INTERIOR CELLS
C
      DO 200 IROW=2,NROWS-1
         DO 201 JCOL=2,NCOLS-1
c234567890
      D(1)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL-1))*PBMAP(IROW-1,JCOL-1)
      D(2)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL  ))*PBMAP(IROW-1,JCOL  )
      D(3)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL+1))*PBMAP(IROW-1,JCOL+1)
      D(4)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL-1))*PBMAP(IROW  ,JCOL-1)
      D(5)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL+1))*PBMAP(IROW  ,JCOL+1)
      D(6)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL-1))*PBMAP(IROW+1,JCOL-1)
      D(7)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL  ))*PBMAP(IROW+1,JCOL  )
      D(8)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL+1))*PBMAP(IROW+1,JCOL+1)
	    BIG=0.D0
	    IID=0
	    DO 1202 II=1,8
           IF(D(II) .GT. BIG)THEN
            BIG=D(II)
	      IID=II
	     END IF
 1202     CONTINUE
          IF(IID .EQ. 0)THEN
C PIT OR OUTLET
           IF((IROW .EQ. LOY).AND.(JCOL .EQ. LOX))THEN
C THIS IS THE OUTLET
            DMAP(IROW,JCOL)=0.0
	      VX(IROW,JCOL)=0
	      VY(IROW,JCOL)=0
	     ELSE IF(PBMAP(IROW,JCOL) .GT. 0.0)THEN
C THIS IS A PIT OR CONCENTRATED FLOW CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=HEAD(IROW,JCOL)-HEAD(LOY,LOX)
            DIST=SQRT((XG(JCOL)-LOX)**2 +
     1                (YG(IROW)-LOY)**2  )
            VX(IROW,JCOL)=CHANNEL*SQRT(VX(IROW,JCOL)/DIST)
	      VY(IROW,JCOL)=(DIST*3.25D0)/VX(IROW,JCOL)
           ELSE
C THIS IS A BOUNDARY CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=-1.0
	      VY(IROW,JCOL)=-1.0
	     END IF
C A DOWNHILL DIRECTION EXISTS, USE THE DIFFERENCE AND DIRECTION
          ELSE IF(IID .EQ. 1)THEN
C USE D1 EQUATIONS
          DMAP(IROW,JCOL)=1.0
          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(1)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 2)THEN
C USE D2 EQUATIONS
          DMAP(IROW,JCOL)=2.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(2)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 3)THEN
C USE D3 EQUATIONS
          DMAP(IROW,JCOL)=3.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(3)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 4)THEN
C USE D4 EQUATIONS
          DMAP(IROW,JCOL)=4.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(4)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 5)THEN
C USE D5 EQUATIONS
          DMAP(IROW,JCOL)=5.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(5)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 6)THEN
C USE D6 EQUATIONS
          DMAP(IROW,JCOL)=6.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(6)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 7)THEN
C USE D7 EQUATIONS
          DMAP(IROW,JCOL)=7.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(7)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 8)THEN
C USE D8 EQUATIONS
          DMAP(IROW,JCOL)=8.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(8)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE
	    END IF
 201     CONTINUE
 200  CONTINUE
C
C BOUNDING RECTANGLE
C

C LEFT
      DO 210 IROW=2,NROWS-1
C CHANGED ARRAY ADDRESSING 2019-0911
         DO 211 JCOL=1,1
C	   D(1)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL-1))*PBMAP(IROW-1,JCOL-1)
      D(1)=0
      D(2)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL  ))*PBMAP(IROW-1,JCOL  )
      D(3)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL+1))*PBMAP(IROW-1,JCOL+1)
C	   D(4)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL-1))*PBMAP(IROW  ,JCOL-1)
      D(4)=0
      D(5)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL+1))*PBMAP(IROW  ,JCOL+1)
C	   D(6)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL-1))*PBMAP(IROW+1,JCOL-1)
      D(6)=0
      D(7)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL  ))*PBMAP(IROW+1,JCOL  )
      D(8)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL+1))*PBMAP(IROW+1,JCOL+1)
	    BIG=0.D0
	    IID=0
	    DO 1212 II=1,8
           IF(D(II) .GT. BIG)THEN
            BIG=D(II)
	      IID=II
	     END IF
 1212     CONTINUE
          IF(IID .EQ. 0)THEN
C PIT OR OUTLET
           IF((IROW .EQ. LOY).AND.(JCOL .EQ. LOX))THEN
C THIS IS THE OUTLET
            DMAP(IROW,JCOL)=0.0
	      VX(IROW,JCOL)=0
	      VY(IROW,JCOL)=0
	     ELSE IF(PBMAP(IROW,JCOL) .GT. 0.0)THEN
C THIS IS A PIT OR CONCENTRATED FLOW CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=HEAD(IROW,JCOL)-HEAD(LOY,LOX)
            DIST=SQRT((XG(JCOL)-LOX)**2 +
     1                (YG(IROW)-LOY)**2  )
            VX(IROW,JCOL)=CHANNEL*SQRT(VX(IROW,JCOL)/DIST)
	      VY(IROW,JCOL)=(DIST*3.25D0)/VX(IROW,JCOL)
           ELSE
C THIS IS A BOUNDARY CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=-1.0
	      VY(IROW,JCOL)=-1.0
	     END IF
C A DOWNHILL DIRECTION EXISTS, USE THE DIFFERENCE AND DIRECTION
          ELSE IF(IID .EQ. 1)THEN
C USE D1 EQUATIONS
          DMAP(IROW,JCOL)=1.0
          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(1)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 2)THEN
C USE D2 EQUATIONS
          DMAP(IROW,JCOL)=2.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(2)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 3)THEN
C USE D3 EQUATIONS
          DMAP(IROW,JCOL)=3.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(3)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 4)THEN
C USE D4 EQUATIONS
          DMAP(IROW,JCOL)=4.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(4)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 5)THEN
C USE D5 EQUATIONS
          DMAP(IROW,JCOL)=5.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(5)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 6)THEN
C USE D6 EQUATIONS
          DMAP(IROW,JCOL)=6.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(6)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 7)THEN
C USE D7 EQUATIONS
          DMAP(IROW,JCOL)=7.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(7)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 8)THEN
C USE D8 EQUATIONS
          DMAP(IROW,JCOL)=8.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(8)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE
	    END IF
 211     CONTINUE
 210  CONTINUE

C
C RIGHT
C
      DO 220 IROW=2,NROWS-1
C Change array indexing 2019-09-11
         DO 221 JCOL=NCOLS,NCOLS
      D(1)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL-1))*PBMAP(IROW-1,JCOL-1)
      D(2)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL  ))*PBMAP(IROW-1,JCOL  )
C	   D(3)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL+1))*PBMAP(IROW-1,JCOL+1)
      D(3)=0
      D(4)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL-1))*PBMAP(IROW  ,JCOL-1)
C	   D(5)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL+1))*PBMAP(IROW  ,JCOL+1)
      D(5)=0
      D(6)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL-1))*PBMAP(IROW+1,JCOL-1)
      D(7)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL  ))*PBMAP(IROW+1,JCOL  )
C	   D(8)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL+1))*PBMAP(IROW+1,JCOL+1)
      D(8)=0
	    BIG=0.D0
	    IID=0
	    DO 1222 II=1,8
           IF(D(II) .GT. BIG)THEN
            BIG=D(II)
	      IID=II
	     END IF
 1222     CONTINUE
          IF(IID .EQ. 0)THEN
C PIT OR OUTLET
           IF((IROW .EQ. LOY).AND.(JCOL .EQ. LOX))THEN
C THIS IS THE OUTLET
            DMAP(IROW,JCOL)=0.0
	      VX(IROW,JCOL)=0
	      VY(IROW,JCOL)=0
	     ELSE IF(PBMAP(IROW,JCOL) .GT. 0.0)THEN
C THIS IS A PIT OR CONCENTRATED FLOW CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=HEAD(IROW,JCOL)-HEAD(LOY,LOX)
            DIST=SQRT((XG(JCOL)-LOX)**2 +
     1                (YG(IROW)-LOY)**2  )
            VX(IROW,JCOL)=CHANNEL*SQRT(VX(IROW,JCOL)/DIST)
	      VY(IROW,JCOL)=(DIST*3.25D0)/VX(IROW,JCOL)
           ELSE
C THIS IS A BOUNDARY CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=-1.0
	      VY(IROW,JCOL)=-1.0
	     END IF
C A DOWNHILL DIRECTION EXISTS, USE THE DIFFERENCE AND DIRECTION
          ELSE IF(IID .EQ. 1)THEN
C USE D1 EQUATIONS
          DMAP(IROW,JCOL)=1.0
          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(1)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 2)THEN
C USE D2 EQUATIONS
          DMAP(IROW,JCOL)=2.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(2)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 3)THEN
C USE D3 EQUATIONS
          DMAP(IROW,JCOL)=3.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(3)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 4)THEN
C USE D4 EQUATIONS
          DMAP(IROW,JCOL)=4.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(4)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 5)THEN
C USE D5 EQUATIONS
          DMAP(IROW,JCOL)=5.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(5)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 6)THEN
C USE D6 EQUATIONS
          DMAP(IROW,JCOL)=6.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(6)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 7)THEN
C USE D7 EQUATIONS
          DMAP(IROW,JCOL)=7.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(7)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 8)THEN
C USE D8 EQUATIONS
          DMAP(IROW,JCOL)=8.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(8)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE
	    END IF
 221     CONTINUE
 220  CONTINUE

C
C TOP
C
      DO 230 IROW=1,1
         DO 231 JCOL=2,NCOLS-1
C changed array indexing 2019-09-11
C	   D(1)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL-1))*PBMAP(IROW-1,JCOL-1)
C	   D(2)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL  ))*PBMAP(IROW-1,JCOL  )
C	   D(3)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL+1))*PBMAP(IROW-1,JCOL+1)
      D(1)=0
      D(2)=0
      D(3)=0
      D(4)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL-1))*PBMAP(IROW  ,JCOL-1)
      D(5)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL+1))*PBMAP(IROW  ,JCOL+1)
      D(6)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL-1))*PBMAP(IROW+1,JCOL-1)
      D(7)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL  ))*PBMAP(IROW+1,JCOL  )
      D(8)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL+1))*PBMAP(IROW+1,JCOL+1)

	    BIG=0.D0
	    IID=0
	    DO 1232 II=1,8
           IF(D(II) .GT. BIG)THEN
            BIG=D(II)
	      IID=II
	     END IF
 1232     CONTINUE
          IF(IID .EQ. 0)THEN
C PIT OR OUTLET
           IF((IROW .EQ. LOY).AND.(JCOL .EQ. LOX))THEN
C THIS IS THE OUTLET
            DMAP(IROW,JCOL)=0.0
	      VX(IROW,JCOL)=0
	      VY(IROW,JCOL)=0
	     ELSE IF(PBMAP(IROW,JCOL) .GT. 0.0)THEN
C THIS IS A PIT OR CONCENTRATED FLOW CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=HEAD(IROW,JCOL)-HEAD(LOY,LOX)
            DIST=SQRT((XG(JCOL)-LOX)**2 +
     1                (YG(IROW)-LOY)**2  )
            VX(IROW,JCOL)=CHANNEL*SQRT(VX(IROW,JCOL)/DIST)
	      VY(IROW,JCOL)=(DIST*3.25D0)/VX(IROW,JCOL)
           ELSE
C THIS IS A BOUNDARY CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=-1.0
	      VY(IROW,JCOL)=-1.0
	     END IF
C A DOWNHILL DIRECTION EXISTS, USE THE DIFFERENCE AND DIRECTION
          ELSE IF(IID .EQ. 1)THEN
C USE D1 EQUATIONS
          DMAP(IROW,JCOL)=1.0
          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(1)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 2)THEN
C USE D2 EQUATIONS
          DMAP(IROW,JCOL)=2.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(2)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 3)THEN
C USE D3 EQUATIONS
          DMAP(IROW,JCOL)=3.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(3)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 4)THEN
C USE D4 EQUATIONS
          DMAP(IROW,JCOL)=4.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(4)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 5)THEN
C USE D5 EQUATIONS
          DMAP(IROW,JCOL)=5.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(5)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 6)THEN
C USE D6 EQUATIONS
          DMAP(IROW,JCOL)=6.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(6)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 7)THEN
C USE D7 EQUATIONS
          DMAP(IROW,JCOL)=7.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(7)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 8)THEN
C USE D8 EQUATIONS
          DMAP(IROW,JCOL)=8.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(8)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE
	    END IF
 231     CONTINUE
 230  CONTINUE

C
C BOTTOM
C
      DO 240 IROW=NROWS,NROWS
         DO 241 JCOL=2,NCOLS-1
C changed array indexing 2019-09-11
      D(1)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL-1))*PBMAP(IROW-1,JCOL-1)
      D(2)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL  ))*PBMAP(IROW-1,JCOL  )
      D(3)=(HEAD(IROW,JCOL)-HEAD(IROW-1,JCOL+1))*PBMAP(IROW-1,JCOL+1)
      D(4)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL-1))*PBMAP(IROW  ,JCOL-1)
      D(5)=(HEAD(IROW,JCOL)-HEAD(IROW  ,JCOL+1))*PBMAP(IROW  ,JCOL+1)
C	   D(6)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL-1))*PBMAP(IROW+1,JCOL-1)
C	   D(7)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL  ))*PBMAP(IROW+1,JCOL  )
C	   D(8)=(HEAD(IROW,JCOL)-HEAD(IROW+1,JCOL+1))*PBMAP(IROW+1,JCOL+1)
      D(6)=0
      D(7)=0
      D(8)=0
	    BIG=0.D0
	    IID=0
	    DO 1242 II=1,8
           IF(D(II) .GT. BIG)THEN
            BIG=D(II)
	      IID=II
	     END IF
 1242     CONTINUE
          IF(IID .EQ. 0)THEN
C PIT OR OUTLET
           IF((IROW .EQ. LOY).AND.(JCOL .EQ. LOX))THEN
C THIS IS THE OUTLET
            DMAP(IROW,JCOL)=0.0
	      VX(IROW,JCOL)=0
	      VY(IROW,JCOL)=0
	     ELSE IF(PBMAP(IROW,JCOL) .GT. 0.0)THEN
C THIS IS A PIT OR CONCENTRATED FLOW CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=HEAD(IROW,JCOL)-HEAD(LOY,LOX)
            DIST=SQRT((XG(JCOL)-LOX)**2 +
     1                (YG(IROW)-LOY)**2  )
            VX(IROW,JCOL)=CHANNEL*SQRT(VX(IROW,JCOL)/DIST)
	      VY(IROW,JCOL)=(DIST*3.25D0)/VX(IROW,JCOL)
           ELSE
C THIS IS A BOUNDARY CELL
	      DMAP(IROW,JCOL)=10.0*PBMAP(IROW,JCOL)-1.0
	      VX(IROW,JCOL)=-1.0
	      VY(IROW,JCOL)=-1.0
	     END IF
C A DOWNHILL DIRECTION EXISTS, USE THE DIFFERENCE AND DIRECTION
          ELSE IF(IID .EQ. 1)THEN
C USE D1 EQUATIONS
          DMAP(IROW,JCOL)=1.0
          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(1)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 2)THEN
C USE D2 EQUATIONS
          DMAP(IROW,JCOL)=2.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(2)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 3)THEN
C USE D3 EQUATIONS
          DMAP(IROW,JCOL)=3.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(3)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)
          ELSE IF(IID .EQ. 4)THEN
C USE D4 EQUATIONS
          DMAP(IROW,JCOL)=4.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(4)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 5)THEN
C USE D5 EQUATIONS
          DMAP(IROW,JCOL)=5.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(5)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 6)THEN
C USE D6 EQUATIONS
          DMAP(IROW,JCOL)=6.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(6)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 7)THEN
C USE D7 EQUATIONS
          DMAP(IROW,JCOL)=7.0

	    VX(IROW,JCOL)=CONVEYANCE*SQRT(D(7)*DXINV)
	    VY(IROW,JCOL)=(DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE IF(IID .EQ. 8)THEN
C USE D8 EQUATIONS
          DMAP(IROW,JCOL)=8.0

          VX(IROW,JCOL)=CONVEYANCE*SQRT(D(8)*DXINV*DSQRTIV)
	    VY(IROW,JCOL)=(SQRT(2.D0)*DELTAX*3.25D0)/VX(IROW,JCOL)

          ELSE
	    END IF
 241     CONTINUE
 240  CONTINUE
C
C WRITE VELOCITY FIELDS TO OUTPUT FOR ERROR CHECKING
C
C USEFUL FOR DEBUGGING
C
CDEBUG      WRITE(*,*)'VELOCITY.MAP'
CDEBUG      CALL PARRAY2D(VX,NRMAX,NCMAX,NROWS,NCOLS)
CDEBUG      WRITE(*,*)'TRAVEL TIME.MAP'
CDEBUG      CALL PARRAY2D(VY,NRMAX,NCMAX,NROWS,NCOLS)
C
      RETURN
 1001 FORMAT(1X,21(F7.3,1X))

	END
C*********************************************************************************
      SUBROUTINE BUILDGRID(XG,YG,NRMAX,NCMAX,NROWS,NCOLS,DELTAX)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION XG(NCMAX),YG(NRMAX)
C
C T.G. CLEVELAND 2005_0125
C
C
C COMPUTE COMPUTATIONAL GRID COORDINATES -- GRID COORDINATES ARE CELL CENTERS
C
      IROW=1
      JCOL=1
      XG(JCOL)=0.5D0*DELTAX
      YG(IROW)=0.5D0*DELTAX
      DO 401 IROW=2,NROWS
        YG(IROW)=YG(IROW-1)+DELTAX
 401  CONTINUE
      DO 402 JCOL=2,NCOLS
        XG(JCOL)=XG(JCOL-1)+DELTAX
 402  CONTINUE
      RETURN
	END
C*********************************************************************************
      SUBROUTINE MOVEPART(XP,YP,XG,YG,VX,VY,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,IP,DELTAT,DELTAX,
     2                    HEAD,TRAN,DMAP,TP,LOX,LOY)
C
C T.G. CLEVELAND 2005_0201 
C
C
C SUBROTUINE TO MOVE A SINGLE PARTICLE OF INDEX IP IN THE PARTICLE ATTRIBUTE ARRAY
C
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION XP(NPMAX),YP(NPMAX),TP(NPMAX)
      DIMENSION VX(NRMAX,NCMAX),VY(NRMAX,NCMAX)
      DIMENSION XG(NCMAX),YG(NRMAX)
      DIMENSION HEAD(NRMAX,NCMAX),DMAP(NRMAX,NCMAX)
C
C LOCATE THE PARTICLE ARRAY INDEX
C
      CALL FINDPART(XP,YP,XG,YG,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,IP,LPX,LPY)
C
C FIND DIRECTION TO MOVE
C
      DMOVE=DMAP(LPY,LPX)
C
C FIND TIME TO MOVE
C
      TMOVE=VY(LPY,LPX)
      
      FLAG=0
C
C MOVE THE PARTICLE
C
           IF(DMOVE .EQ. 1.0)THEN
	 XP(IP)=XG(LPX-1)
	 YP(IP)=YG(LPY-1)
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 2.0)THEN
	 XP(IP)=XG(LPX  )
	 YP(IP)=YG(LPY-1)
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 3.0)THEN
	 XP(IP)=XG(LPX+1)
	 YP(IP)=YG(LPY-1)
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 4.0)THEN
	 XP(IP)=XG(LPX-1)
	 YP(IP)=YG(LPY  )
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 5.0)THEN
	 XP(IP)=XG(LPX+1)
	 YP(IP)=YG(LPY  )
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 6.0)THEN
	 XP(IP)=XG(LPX-1)
	 YP(IP)=YG(LPY+1)
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 7.0)THEN
	 XP(IP)=XG(LPX  )
	 YP(IP)=YG(LPY+1)
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 8.0)THEN
	 XP(IP)=XG(LPX+1)
	 YP(IP)=YG(LPY+1)
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 9.0)THEN
	 XP(IP)=XG(LOX)
	 YP(IP)=YG(LOY)
	 TP(IP)=TP(IP)+TMOVE
	ELSE IF(DMOVE .EQ. 0.0)THEN
      if(FLAG .ne. 0)THEN
       WRITE(*,*)'ALREADY IN OUTLET, PARTICLE SHOULD BE REMOVED'
	 WRITE(*,*)'A SINGLE INSTANCE OF THIS MESSAGE IS EXPECTED'
	 WRITE(*,*)'IP,LPX,LPY =',IP,LPX,LPY
	 WRITE(*,*)'DMOVE,TMOVE  =',DMOVE,TMOVE
      end if
	ELSE IF(DMOVE .LT. 0.0)THEN
       WRITE(*,*)'ERROR -- ATTEMPTING TO MOVE IN BOUNDARY ARRAY'
	 WRITE(*,*)'IP,LPX,LPY =',IP,LPX,LPY
	 WRITE(*,*)'DMOVE,TMOVE  =',DMOVE,TMOVE
	END IF
	RETURN
	END
C*********************************************************************************
      SUBROUTINE FINDPART(XP,YP,XG,YG,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,IP,LPX,LPY)
C
C SUBROTUINE TO FIND A SINGLE PARTICLE OF INDEX IP IN THE PARTICLE ATTRIBUTE ARRAY
C AND DETERMINE ITS CELL INDICES
C
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION XP(NPMAX),YP(NPMAX)
      DIMENSION XG(NCMAX),YG(NRMAX)
C
C SEARCH DISTANCE
C
	BIG=1.D9
C
C LOCATE NEAREST GRID POINT
C
      DIST1=BIG
      DIST2=BIG
         DO 7002 IROW=1,NROWS
            DO 7003 JCOL=1,NCOLS
               DIST2=(XP(IP)-XG(JCOL))**2 + (YP(IP)-YG(IROW))**2
               IF( DIST2 .LT. DIST1)THEN
                   DIST1=DIST2
                   LPX=JCOL
                   LPY=IROW
               END IF
 7003       CONTINUE
 7002   CONTINUE
	RETURN
	END
C****************************************************************
      SUBROUTINE PARRAY2D(ARRAY,NRP,NCP,NRL,NCL)
C
C PRINT CONTENTS OF 2-D ARRAY
C
C ARRAY IS ARRAY TO PRINT
C  NRP = PHYSICAL ROW DIMENSION
C  NCP = PHYSICAL COLUMN DIMENSION
C  NRL = LOGICAL ROW DIMENSION
C  NCL = LOGICAL COLUMN DIMENSION
C
C CURRENT FORMAT IS 21 FIELDS OF 7+1 SPACES
C
C
	REAL*8 ARRAY
	DIMENSION ARRAY(NRP,NCP)
	DO 501 IROW=1,NRL
         WRITE(*,1001)(ARRAY(IROW,JCOL),JCOL=1,NCL)
 501  CONTINUE
      RETURN
 1001 FORMAT(1X,21(F7.1,1X))
      END
C******************************************************************
      SUBROUTINE PARRAY1D(ARRAY,NRP,NRL)
C
C PRINT CONTENTS OF 1D ARRAY -- USEFUL FOR DEBUGGING
C
C ARRAY IS ARRAY TO PRINT
C  NRP = PHYSICAL ROW DIMENSION
C  NRL = LOGICAL ROW DIMENSION
C
C CURRENT FORMAT IS 2 FIELDS OF 1+5 AND 12+2
C
C
	REAL*8 ARRAY
	DIMENSION ARRAY(NRP)
	DO 501 IROW=1,NRL
	 WRITE(*,1001)IROW,ARRAY(IROW)
 501  CONTINUE
      RETURN
 1001 FORMAT(1X,I5,2X,F12.6)
      END
C*******************************************************************
      SUBROUTINE MAPPART(XP,YP,XG,YG,PMAP,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,NP)
C
C SUBROUTINE TO CONSTRUCT AN ACCUMULATED PARTICLE MAP
C USEFUL FOR DEBUGGING 
C
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION XP(NPMAX),YP(NPMAX)
      DIMENSION XG(NCMAX),YG(NRMAX)
      DIMENSION PMAP(NRMAX,NCMAX)
C
C CLEAR THE MAP
C
	CALL CARRAY2D(PMAP,NRMAX,NCMAX,NROWS,NCOLS)
C
C POPULATE THE MAP
C
	DO 1001 IP=1,NP
      CALL FINDPART(XP,YP,XG,YG,NRMAX,NCMAX,NPMAX,
     1                    NROWS,NCOLS,IP,LPX,LPY)
	PMAP(LPY,LPX)=PMAP(LPY,LPX)+1.0
 1001 CONTINUE
      RETURN
	END
C********************************************************************
      SUBROUTINE CARRAY2D(ARRAY,NRP,NCP,NRL,NCL)
C
C SUBROUTINE TO CLEAR CONTENTS OF AN ARRAY
C CLEARS LOGICAL DIMENSION ONLY
C
	REAL*8 ARRAY
	DIMENSION ARRAY(NRP,NCP)
	DO 501 IROW=1,NRL
       DO 502 JCOL=1,NCL
	  ARRAY(IROW,JCOL)=0.D0
 502   CONTINUE
 501  CONTINUE
      RETURN
      END
C*********************************************************************
      function valmax2d(array,nrp,ncp,nrl,ncl)
c 
c 2005_1101 tgc
c
c function determines the maximum numerical value in 2d array that has
c physical dimension nrp x ncp (rows x columns) 
c logical  dimension nrl x ncl (rows x columns)
c
      real*8 valmax2d
      real*8 array
      dimension array(nrp,ncp)
      valmax2d=-1.d99
      do 101 irow=1,nrl
       do 102 jcol=1,ncl
        valmax2d=max(valmax2d,array(irow,jcol))  
 102   continue
 101  continue
      return
      end
c
      function valmin2d(array,nrp,ncp,nrl,ncl)
c
c 2005_1101 tgc
c
c function determines the minimum numerical value in 2d array that has
c physical dimension nrp x ncp
c logical dimension  nrl x ncl
c
      real*8 valmin2d
      real*8 array
      dimension array(nrp,ncp)
      valmin2d=1.d99
      do 101 irow=1,nrl
       do 102 jcol=1,ncl
        valmin2d=min(valmin2d,array(irow,jcol))
 102   continue
 101  continue
      return
      end
c

C*********************************************************************
      SUBROUTINE sort(n,arr)
c
c sorting algorithm from Numerical Recipes
c modified by t.g cleveland for double precision reals
c 2005_0202
c
c arr is array name to sort
c   n is logical dimension
c
c notes: arrays must be single subscript, this routine will not
c        properly sort a column or row of a 2d array.
c   
c        sort is ascending (from small to big)
c        sort is in-place
c
      INTEGER n,M,NSTACK
      REAL*8 arr(n)
      PARAMETER (M=7,NSTACK=50)
      INTEGER i,ir,j,jstack,k,l,istack(NSTACK)
      REAL*8 a,temp
      jstack=0
      l=1
      ir=n
1     if(ir-l.lt.M)then
        do 12 j=l+1,ir
          a=arr(j)
          do 11 i=j-1,l,-1
            if(arr(i).le.a)goto 2
            arr(i+1)=arr(i)
11        continue
          i=l-1
2         arr(i+1)=a
12      continue
        if(jstack.eq.0)return
        ir=istack(jstack)
        l=istack(jstack-1)
        jstack=jstack-2
      else
        k=(l+ir)/2
        temp=arr(k)
        arr(k)=arr(l+1)
        arr(l+1)=temp
        if(arr(l).gt.arr(ir))then
          temp=arr(l)

          arr(l)=arr(ir)
          arr(ir)=temp
        endif
        if(arr(l+1).gt.arr(ir))then
          temp=arr(l+1)
          arr(l+1)=arr(ir)
          arr(ir)=temp
        endif
        if(arr(l).gt.arr(l+1))then
          temp=arr(l)
          arr(l)=arr(l+1)
          arr(l+1)=temp
        endif
        i=l+1
        j=ir
        a=arr(l+1)
3       continue
          i=i+1
        if(arr(i).lt.a)goto 3
4       continue
          j=j-1
        if(arr(j).gt.a)goto 4
        if(j.lt.i)goto 5
        temp=arr(i)
        arr(i)=arr(j)
        arr(j)=temp
        goto 3
5       arr(l+1)=arr(j)
        arr(j)=a
        jstack=jstack+2

        if(jstack.gt.NSTACK)then
           write(*,*) 'NSTACK too small in sort'
           stop
        end if
        if(ir-i+1.ge.j-l)then
          istack(jstack)=ir
          istack(jstack-1)=i
          ir=j-1
        else
          istack(jstack)=j-1
          istack(jstack-1)=l
          l=i
        endif
      endif
      goto 1
      END
C*********************************************************************
      FUNCTION BDF2RMAN(BDF)
      REAL*8 BDF,BDF2RMAN
C THIS FUNCTION CONVERTS A CATEGORICAL VARIABLE BDF INTO RMAN ADJUSTMENT
C CONVERSIONS ARE HARD-WIRED INTO FUNCTION AND ARE DETERMINED BY ANALYST BEFORE
C PRODUCTION SIMULATIONS
      IF(BDF .EQ. 12.0)THEN
       BDF2RMAN=3.0D0
       RETURN
      ELSE IF(BDF .EQ. 11.0)THEN
       BDF2RMAN=3.5D0
       RETURN
      ELSE IF(BDF .EQ. 10.0)THEN
       BDF2RMAN=4.0D0
       RETURN
      ELSE IF(BDF .EQ.  9.0)THEN
       BDF2RMAN=4.5D0
       RETURN
      ELSE IF(BDF .EQ.  8.0)THEN
       BDF2RMAN=5.0D0
       RETURN
      ELSE IF(BDF .EQ.  7.0)THEN
       BDF2RMAN=5.5D0
       RETURN
      ELSE IF(BDF .EQ.  6.0)THEN
       BDF2RMAN=6.0D0
       RETURN
      ELSE IF(BDF .EQ.  5.0)THEN
       BDF2RMAN=6.5D0
       RETURN
      ELSE IF(BDF .EQ.  4.0)THEN
       BDF2RMAN=7.0D0
       RETURN
      ELSE IF(BDF .EQ.  3.0)THEN
       BDF2RMAN=7.5D0
       RETURN
      ELSE IF(BDF .EQ.  2.0)THEN
       BDF2RMAN=8.0D0
       RETURN
      ELSE IF(BDF .EQ.  1.0)THEN
       BDF2RMAN=8.5D0
       RETURN
      ELSE IF(BDF .EQ.  0.0)THEN
       BDF2RMAN=9.0D0
       RETURN
      ELSE 
       BDF2RMAN=4.0D0
       WRITE(*,*)'DATA FILE ERROR IN BDF 2 RMAN'
       RETURN
      END IF
      END







