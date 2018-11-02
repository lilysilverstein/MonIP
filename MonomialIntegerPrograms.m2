newPackage (
  "MonomialIntegerPrograms",
  Version=>"0.1",
  Authors => {{
      Name => "Lily Silverstein", 
      Email => "lsilver@math.ucdavis.edu",
      HomePage => "math.ucdavis.edu/~lsilver"
      }},
  Headline => "using integer programming for fast computations with monomial ideals",
  Configuration => {
      "CustomPath" => ""
      },
  PackageImports => {"LexIdeals"},
  DebuggingMode => true
)

-------------
-- exports --
-------------
export {
    "codimensionIP",    
    "degreeIP",
    "dimensionIP",
    "monomialIdealsWithHilbertFunction",
    "topMinimalPrimesIP",
    "KnownDim"
    }
exportMutable {
    "ScipPrintLevel"
    }

userPath = MonomialIntegerPrograms#Options#Configuration#"CustomPath";

ScipPath = if userPath == "" then(
    print("Using default executable name \"scip\".\nTo change this, load package using CustomPath option.");
    "scip") else userPath;

ScipPrintLevel = 1;
print("Current value of ScipPrintLevel is 1.")
-------------
-- methods --
-------------

codimensionIP = method();
codimensionIP (MonomialIdeal) := I -> (
    (numgens ring I) - dimensionIP(I)
    )

dimensionIP = method();
dimensionIP (MonomialIdeal) := I -> (
    (dir, zimplFile, solFile, errorFile, detailsFile) := tempDirectoryAndFiles("dim");
    zimplFile << dimensionIPFormulation(I) << close;
    run(concatenate("(",ScipPath, 
	    " -c 'read ", zimplFile,
	    "' -c 'optimize'",
	    " -c 'display solution ",
	    "' -c quit;) 1>",
	    solFile,
	    " 2>",
	    errorFile));
    printStatement({zimplFile, solFile, errorFile, "Dimension", dir});
    readScipSolution(solFile)
    )

degreeIP = method( 
    Options => {KnownDim => -1}
    );
degreeIP (MonomialIdeal) := o -> I -> (
    if not isSquareFree I then(
	error("This method currently implemented for squarefree monomial ideals only!")
	);
    --waiting to see if polarize function is accepted into M2 core
    objValue := if o.KnownDim >= 0 then o.KnownDim else dimensionIP(I);
    (dir, zimplFile, solFile, errorFile, detailsFile) := tempDirectoryAndFiles("deg");    
    zimplFile << degreeIPFormulation(I, objValue) << close;
    run(concatenate("(",ScipPath, 
	    " -c 'set emphasis counter'",
	    " -c 'set constraints countsols collect FALSE'",     	    
	    " -c 'read ", zimplFile, "'",
	    " -c 'count'",
	    " -c quit;)",
	    " 1>",
	    solFile,
	    " 2>",
	    errorFile
	    ));
    printStatement({zimplFile, solFile, errorFile, "Degree", dir});
    readScipCount(solFile)
    )

monomialIdealsWithHilbertFunction = method();
monomialIdealsWithHilbertFunction (List, Ring) := (D, R) -> (
    if not isHF D then error(
	"impossible values for a Hilbert function! Make sure your Hilbert function corresponds to the QUOTIENT RING of a homogeneous ideal"
	);
    n := numgens R;
    Dlist := apply(#D, i -> binomial(n+i-1,i)-D#i);
    (dir, zimplFile, solFile, errorFile, detailsFile) := tempDirectoryAndFiles("hilbert");            
    zimplFile << hilbertIPFormulation(Dlist, n) << close;
    run(concatenate("(",ScipPath, 
	    " -c 'set emphasis counter'",
	    " -c 'set constraints countsols collect TRUE'",     
	    " -c 'read ", zimplFile,
	    "' -c 'count'",
	    " -c 'write allsolutions ",
	    solFile,
	    "' -c quit;)",
	    " 1>",
	    detailsFile,
	    " 2>",
	    errorFile));
    printStatement({zimplFile, solFile, errorFile, "Hilbert", dir});
    readAllMonomialIdeals(solFile, R)
    )

topMinimalPrimesIP = method(
    Options => {KnownDim => -1}
    );
topMinimalPrimesIP (MonomialIdeal) := o -> I -> (
    if I == monomialIdeal(1_(ring I)) then return I;
    k := if o.KnownDim >= 0 then o.KnownDim else dimensionIP(I);
    (dir, zimplFile, solFile, errorFile, detailsFile) := tempDirectoryAndFiles("comps");        
    zimplFile << degreeIPFormulation(I, k) << close;
    run(concatenate("(",ScipPath, 
	    " -c 'set emphasis counter'",
	    " -c 'set constraints countsols collect TRUE'",     	    
	    " -c 'read ", zimplFile,
	    "' -c 'count'",
	    " -c 'write allsolutions ",
	    solFile,
	    "' -c quit;)",
	    " 1>",
	    detailsFile,
	    " 2>",
	    errorFile));
    printStatement({zimplFile, solFile, errorFile, "Minimal primes of codim "|k, dir});
    readAllPrimes(solFile, ring I)
    )

----------------------
-- internal methods --
----------------------

degreeIPFormulation = method();
degreeIPFormulation (List, ZZ, ZZ) := (A, n, knownDim) -> (
    concatenate(dimensionIPFormulation(A, n),"\n",
	"subto dim: sum <i> in N: X[i] == "|toString(knownDim)|";")
    )
degreeIPFormulation (MonomialIdeal, ZZ) := (I, knownDim) -> (
    degreeIPFormulation(monIdealToSupportSets(I), #gens ring I, knownDim)
    )

dimensionIPFormulation = method();
dimensionIPFormulation (List, ZZ) := (A, n) -> (
    concatenate({"set N := {0 .. ",toString(n-1),"};\n",
        "var X[N] binary;\n","maximize obj: sum <i> in N: X[i];\n",
        demark("\n", for i from 0 to #A-1 list(
	concatenate({"subto constraint",toString(i),": ",
	demark("+",apply(A#i, e -> "X["|toString(e)|"]")),
	" <= ",toString(#(A#i)-1)|";"})))
    })
)
dimensionIPFormulation (MonomialIdeal) := (I) -> (
    dimensionIPFormulation(monIdealToSupportSets I, #gens ring I)
    )

hilbertIPFormulation = method();
hilbertIPFormulation (List, ZZ) := (D, n) -> (
    varsCommas := demark(",", toList vars(0..n-1));
    varsPluses := demark("+", toList vars(0..n-1));
    varsPlusOne := j -> (
	demark(",", apply(n, k -> if k==j then toString(vars(k))|"+1" else toString(vars(k))))
	);
    concatenate({"param maxD := ",
	    toString(#D-1),";\n",
	    "set D := {0 .. maxD};\n",
	    "set M := {<",varsCommas,"> in ", demark("*", n:"D"),
            " with ", varsPluses," <= maxD};\n",
	    "param p[<degree> in D] := ", demark(", ",apply(#D, i -> "<"|i|">"|D#i)),";\n",
	    "var X[M] binary;\n",
	    "minimize obj: X[", demark(",", n:"0"), "];\n",
	    "subto h: forall <degree> in D do\n",
	    "    sum <", varsCommas, "> in M with ", varsPluses, " == degree: X[",
	    varsCommas, "] == p[degree];\n",
	    "subto ideal: forall <", varsCommas, "> in M with ", varsPluses, " <= maxD-1 do\n    ",
	    demark(" + ", apply(n, j -> "X["|varsPlusOne(j)|"]")),
	    " - ", toString(n), "*X[", varsCommas, "] >= 0;"
	    })
    )

monIdealToSupportSets = method()
monIdealToSupportSets (MonomialIdeal) := (I) -> (
    apply(first entries mingens I, m -> apply(support m, r -> index r))
    )

printStatement = method();
printStatement (List) := L -> (
    (zimplFile, solFile, errorFile, nickname, dir) := toSequence L;
    if ScipPrintLevel >= 4 then print(get zimplFile);
    if ScipPrintLevel >= 3 then print(get solFile);
    if ScipPrintLevel >= 2 then print(get errorFile);
    if ScipPrintLevel >= 1 then print(nickname|" files saved in directory: "|dir);
)

readAllMonomialIdeals = method()
readAllMonomialIdeals (String, Ring) := (solFile, R) -> (
    n := numgens R;
    L := lines get solFile;
    mons := apply(select("X"|demark(".", n:"#")|".",L#0), a -> product(apply(n, i -> R_i^(value a_(2*i+2)))));
    L = drop(L, 1);
    allSolutions := apply(L, 
	ln -> (
	    l := drop(separate(",",ln), 1);
	    I := monomialIdeal(apply(#l, i -> if value(l#i)==1 then mons#i else 0))
	    )
	)
    )

readAllPrimes = method()
readAllPrimes (String, Ring) := (solFile, R) -> (
    n := numgens R;
    L := lines get solFile;
    mons := apply(select("X#([[:digit:]]+)", L#0), a -> R_(value substring(a, 2)));
    L = drop(L, 1);
    allSolutions := apply(L, 
	ln -> (
	    l := drop(separate(",",ln), 1);
	    l = drop(l, -1);
	    monomialIdeal for i from 0 to #l-1 list if value(l#i)==0 then mons#i else continue
	    )
	)
    )

readScipSolution = method();
readScipSolution (String) := solFile -> (
    solContents := get solFile;
    value first select(///objective value.[[:space:]]+([[:digit:]]+)///, ///\1///, solContents)
)

readScipCount = method();
readScipCount (String) := solFile -> (
    solContents := get solFile;
    value first select(///Feasible Solutions[[:space:]]+:[[:space:]]+([[:digit:]]+)///, ///\1///, solContents)
)

tempDirectoryAndFiles = method()
tempDirectoryAndFiles (String) := (bname) -> (
    dir := temporaryFileName();
    makeDirectory(dir);
    (dir, dir|"/"|bname|".zpl", dir|"/"|bname|".sol", dir|"/"|bname|".errors", dir|"/"|bname|".details")
)

-----------
-- tests --
-----------

TEST ///
R = QQ[x,y,z,w,v];
I = monomialIdeal(x*y*w, x*z*v, y*x, y*z*v);
assert(dimensionIP(I) == 3)
assert(degreeIP(I) == 5)
///

TEST ///
L = {{0,1,3}, {1,2}, {2,3}, {3,4}, {0,4}};
assert(dimensionIP(L, 5) == 2)
assert(dimensionIP(L, 6) == 3)
///

TEST ///
R=QQ[x,y,z];
assert(#monomialIdealsWithHilbertFunction({1,2,1,0},R)==9)
assert(#monomialIdealsWithHilbertFunction({1,3,4,2,1,0},R)==156)
///

TEST /// --hilbert function
R=QQ[x,y,z,w];
assert(#monomialIdealsWithHilbertFunction({1,4,3,1,0},R)==244)
assert(all(monomialIdealsWithHilbertFunction({1,4,10,19,31},R), I -> numgens I == 1))
///

TEST /// --top min primes
R = QQ[x,y,z,w,v];
I = monomialIdeal(x*y*w, x*z*v, y*x, y*z*v);
assert(
    set(topMinimalPrimesIP(I))===set(minimalPrimes I)
    )
J = monomialIdeal(x^2*y*w^3*z, x*y*z*w*v, y*x^8*v, y^5*z*v, x^10, z^10, v^10);
assert(
    topMinimalPrimesIP(J) == {monomialIdeal(x,z,v)}
    )
K = monomialIdeal(x^2*y*w^3*z, x*y*z*w*v, y*x^8*v, y^5*z*v, y*x^10, v*z^10, w*v^10);
assert(
    set(topMinimalPrimesIP(K))===set(select(minimalPrimes(K), p -> 3 == dim p))
    )
L = monomialIdeal(y^12, x*y^3, z*w^3, z*v*y^10, z*x^10, v*z^10, w*v^10, y*v*x*z*w);
assert(
    set(topMinimalPrimesIP(L))===set(select(minimalPrimes(L), p -> 2 == dim p))    
    )
///
-------------------
-- documentation --
-------------------

beginDocumentation()

doc ///
 Key
  MonomialIntegerPrograms
 Headline
  A package for fast monomial ideal computations using constraint integer programming
 Description
  Text
   This package uses integer program reformulations to perform faster
   computations on monomial ideals. The functions currently available
   are:
   
   @TO codimensionIP@--codimension of a monomial ideal
   
   @TO dimensionIP@--dimension of a monomial ideal
   
   @TO degreeIP@--degree of a monomial ideal, currently for squarefree only
   
   @TO topMinimalPrimesIP@--lists all minimal primes of maximum dimension
   
   @TO monomialIdealsWithHilbertFunction@--lists all monomial ideals in a given ring
   with a given Hilbert function
   
   Additional functions are in development.
  
   {\bf Installation and licensing information.}
   
   This package relies on the constraint integer program solver SCIP, which
   is available at @HREF"https://scip.zib.de/"@. This software is free for
   for academic, non-commercial purposes. Notice that SCIP is not distributed 
   under GPL, but under the ZIB Academic License (@HREF"https://scip.zib.de/academic.txt"@).
  
   To install SCIP, click the {\bf Download} tab on the left-hand side of the
   SCIP home page. The easiest method is to install prebuilt binaries (look for the heading
   {\em Installers (install the scipoptsuite in your computer, without source files)}.
   Choose the appropriate Linux, Windows, or MacOS file. The download is free,
   but you will be asked to submit your name and academic institution, to conform to
   the ZIB Academic License requirements, before the download begins.
  
   Under the heading {\em Source Code}, you can find the files for building
   from source. If building from source, you MUST include the source files for
   the modeling language Zimpl in order to use the Monomial Integer 
   Programs package. This will be included if you choose the download named 
   SCIP Optimization Suite, rather than the one named SCIP. Alternatively, download
   SCIP and then follow the {\em ZIMPL} link at the top of the home page to
   download the source files for Zimpl. When building SCIP, you will have to set
   a flag indicating that Zimpl should be built as well. For more information about
   building SCIP visit their online documentation (@HREF "https://scip.zib.de/doc-6.0.0/html/"@)
   and click on {\em Overview} -> {\em Getting started} ->
   {\em Installing SCIP}.
  
   An excellent user guide to using Zimpl can be found at 
   @HREF"https://zimpl.zib.de/download/zimpl.pdf"@. The author, Thorsten
   Koch, requests that research making use of this software please
   cite his 2004 PhD thesis, {\em Rapid Mathematical Programming}. The
   appropriate BibTeX entry can be found here: @HREF"https://zimpl.zib.de/download/zimpl.bib"@.
   Zimpl is distributed under GPL.
  
   Additionally, any research that uses SCIP needs a proper citation. See the
   {\bf How to Cite} tab on their home page.  
     
 SeeAlso
  codimensionIP
  degreeIP
  dimensionIP
  monomialsWithHilbertFunction
  topMinimalPrimesIP
  symbol ScipPrintLevel
///

doc ///
 Key
  symbol ScipPrintLevel
 Headline
  adjust how much solving information is displayed in MonomialIntegerPrograms
 Description
  Text
   {\tt ScipPrintLevel} is a global symbol defined in Monomial Integer Programs 
   using @TO exportMutable@. After the package has been loaded, 
   the user can change the value of ScipPrintLevel at any time, 
   and the specified behavior will immediately apply to all 
   methods implemented in the package.

   Meaningful options for ScipPrintLevel are:
   
   {\bf 0} return the answers to computations only,  suppressing all other printing  
   
   {\bf 1} return the answer, and print to screen the location of the
   temporary directory which contains all the files related to the computation. By 
   default this is a subdirectory of {\tt /tmp/}, see @TO temporaryFileName@.

   {\bf 2} all the above, plus display any error or warning messages 
   generated by SCIP during the computation, i.e. anything sent by SCIP to stderr.
   See note below about warning messages.
   
   {\bf 3} all the above, plus print the solution file generated 
   by SCIP after solving the IP
   
   {\bf 4} all the above, plus print the problem file generated with 
   this package, used as the input to SCIP
   
   {\bf 5} all the above, plus print any other information sent by 
   SCIP to stdout during the solve, if any

   The default value of ScipPrintLevel, set every time
   the package is loaded, is 1.
   
   {\bf Why am I getting warnings/why does the solver report infeasibility for
   the degree count?}

   Computing the degree of a monomial ideal is done by counting the number of feasible solutions
   to a certain integer program. SCIP is generally designed to find a single optimal or feasible
   solution, so to count them it uses the following "trick": every time SCIP encounters a feasible
   solution, it is recorded, then a constraint is added to make this new solution infeasible, and the 
   search is continued. Eventually, all the solutions are recorded and the entire problem has been 
   made "infeasible." Thus the solving details for the degree problem print a final result of 
   "problem is infeasible," but the correct count has been taken. For more details, see the SCIP
   documentation page @HREF"https://scip.zib.de/doc/html/COUNTER.php"@.

 SeeAlso
  MonomialIntegerPrograms
///



doc ///
 Key
  degreeIP
  (degreeIP, MonomialIdeal)
  [degreeIP, KnownDim]
 Headline
  compute the degree of a monomial ideal using integer programming
 Usage
  d = degreeIP(I)
  d = degreeIP(I, KnownDim => k)
 Inputs
  I:MonomialIdeal
  k:ZZ
   if known, the dimension of the ideal (optional)
 Outputs
  d:ZZ
   the degree of $I$. That is, if $k$ is the maximum dimension of
   a coordinate subspace in the variety of $I$, then $degree(I)$ is
   the number of $k$-dimensional subspaces in the variety.
 Description
  Text
   If a {\tt KnownDim} is not provided, {\tt degreeIP} will first
   call {@TO dimensionIP@}($I$) to compute the dimension.
   
   An integer programming formulation of the degree problem is
   written to a temporary file directory, then the SCIP
   Optimization Suite is used to solve the IP. Solving details
   are written to a second file in the temporary directory, before
   outputting the answer.
  Example
   R = QQ[x,y,z,w,v];
   I = monomialIdeal(x*y*w, x*z*v, y*x, y*z*v);
   degreeIP(I, KnownDim => 3)
   degreeIP(I)
  Text
   The location of the temporary directory is printed to the
   screen.

   For more information about the SCIP warning messages, and related
   info on how SCIP counts solutions, see the very end of the
   @TO symbol ScipPrintLevel@ info page. 
 Caveat
  {\tt degreeIP} does not verify that a provided {\tt KnownDim} 
  is correct. Providing the wrong dimension will result in an 
  incorrect degree count (and possibly an infeasible program).
 SeeAlso
  (degree, Ideal)
  dimensionIP
  MonomialIntegerPrograms
  symbol ScipPrintLevel
///

doc ///
 Key
  dimensionIP
  (dimensionIP, MonomialIdeal)
 Headline
  compute the dimension of a monomial ideal using integer programming
 Usage
  k = dimensionIP(I)
 Inputs
  I:MonomialIdeal
 Outputs
  k:ZZ
   the dimension of $I$. That is, $k$ is the maximum dimension of
   a coordinate subspace in the variety of $I$.
 Description
  Example
   R = QQ[x,y,z,w,v];
   I = monomialIdeal(x*y*w, x*z*v, y*x, y*z*v);
   dimensionIP(I)
  Text   
   The location of input/output files for SCIP solving is printed
   to the screen by default. To change this, see @TO symbol ScipPrintLevel@.
  Example
   ScipPrintLevel = 0;
   J = monomialIdeal(x*y^3*z^7, y^4*w*v, z^2*v^8, x*w^3*v^3, y^10, z^10)
   dimensionIP(J) 
  Text
   The dimension of a monomial ideal is equal to the dimension
   of its radical. If $I$ is not squarefree, then {\tt dimensionIP(I)}
   will call {\tt dimensionIP(radical I)}.
 SeeAlso
  (dim, MonomialIdeal)
  codimensionIP
  MonomialIntegerPrograms
  symbol ScipPrintLevel
///

doc ///
 Key
  codimensionIP
  (codimensionIP, MonomialIdeal)
 Headline
  compute the codimension of a monomial ideal using integer programming
 Usage
  c = codimensionIP(I)
 Inputs
  I:MonomialIdeal
 Outputs
  c:ZZ
   the codimension of $I$
 Description
  Text
   This function calls @TO dimensionIP@ and then returns $n$-dimensionIP($I$), where 
   $n$ is the number of variables in the polynomial ring where $I$ is defined.
   The integer programming input and output files created will therefore be named
   "dim.zpl", "dim.errors", etc. as with @TO dimensionIP@. 
  Example
   R = QQ[x,y,z,w,v];
   I = monomialIdeal(x*y*w, x*z*v, y*x, y*z*v);
   codimensionIP(I)
  Text
   The verbosity of every function in the MonomialIntegerPrograms package is controlled with
   @TO symbol ScipPrintLevel@.
  Example
   ScipPrintLevel = 0;
   J = monomialIdeal(x*y^3*z^7, y^4*w*v, z^2*v^8, x*w^3*v^3, y^10, z^10)
   codimensionIP(J) 
  Text
   The dimension of a monomial ideal is equal to the dimension
   of its radical. If $I$ is not squarefree, then {\tt dimensionIP(I)}
   will call {\tt dimensionIP(radical I)}.
 SeeAlso
  (codim, MonomialIdeal)
  dimensionIP
  MonomialIntegerPrograms
  symbol ScipPrintLevel
///

doc ///
 Key
  monomialIdealsWithHilbertFunction
  (monomialIdealsWithHilbertFunction, List, Ring)
 Headline
  find all monomial ideals in a polynomial ring with a particular (partial or complete) Hilbert function
 Usage
  monomialIdealsWithHilbertFunction(L, R)
 Inputs
  L: List
   $\{h(0), h(1), \ldots, h(d)\}$, the values of a valid Hilbert function of a graded ring for degrees $0\ldots d$.
  R: Ring
   a polynomial ring
 Outputs
   :List
    all ideals $I$ of $R$ that satisfy $HF(R/I, i) = h(i)$ for all $0\le i\le d$
 Description
  Text
   Macaulay's Theorem characterizes all integer sequences which may be the Hilbert function of a graded ring. The package
   @TO LexIdeals@ has several functions based on this theorem, including the function @TO isHF@ which takes an integer 
   sequence and returns true if it is a valid (partial) Hilbert function, and false otherwise.
   
   When you call {\tt monomialIdealsWithHilbertFunction(L, R)}, first the function {\tt isHF L} is called to make sure
   that the problem is feasible. 
   
   This documentation page still in progress.
 SeeAlso
  hilbertFunct
  isHF
  LexIdeals
  MonomialIntegerPrograms
  symbol ScipPrintLevel
///

doc ///
 Key
  topMinimalPrimesIP
  (topMinimalPrimesIP, MonomialIdeal)
  [topMinimalPrimesIP, KnownDim]
 Headline
  compute the minimal primes of maximum dimension using integer programming
 Usage
  topMinimalPrimesIP(I)
  topMinimalPrimesIP(I, KnownDim => k)
 Inputs
  I:MonomialIdeal
  k:ZZ
   if known, the dimension of the ideal (optional)
 Outputs
  L:List
   all minimal associated primes of dimension $k$
 Description
  Text
   If a {\tt KnownDim} is not provided, {\tt topMinimalPrimesIP} will first
   call {@TO dimensionIP@}($I$) to compute the dimension.
   
   The IP for this function is similar to the @TO degreeIP@ formulation,
   except that rather than count the number of solutions, SCIP
   uses a sparse data structure to enumerate all feasible solutions.
   
   The location of input/output files for SCIP solving is printed
   to the screen by default. To change this, see @TO symbol ScipPrintLevel@.
  Example
   R = QQ[x,y,z,w,v];
   I = monomialIdeal(y^12, x*y^3, z*w^3, z*v*y^10, z*x^10, v*z^10, w*v^10, y*v*x*z*w);
   ScipPrintLevel = 0;
   minimalPrimes(I)
   apply(oo, p -> dim p)
   topMinimalPrimesIP(I)
  Text
   Notice that if the dimension of a monomial ideal is $k$, each
   of the top minimal primes is generated by $n-k$ variables, where $n$
   is the number of variables in the polynomial ring.
 Caveat
  {\tt topMinimalPrimesIP} does not verify that a provided 
  {\tt KnownDim} is correct. Providing the wrong dimension will 
  result in an incorrect answer or an error.
 SeeAlso
  (topComponents, Ideal)
  degreeIP
  MonomialIntegerPrograms
  symbol ScipPrintLevel
///

viewHelp("MonomialIntegerPrograms")

end--

installPackage("MonomialIntegerPrograms")
restart
needsPackage("MonomialIntegerPrograms", Configuration => {"CustomPath" => "SCIPOptSuite-6.0.0-Linux/bin/scip"})

viewHelp("MonomialIntegerPrograms")
randomFixedDegreeMonomials = method();
randomFixedDegreeMonomials (ZZ, ZZ, ZZ) := (n, D, M) -> (
    for m from 0 to M-1 list(
	mon := {};
	while #mon < D do(
	    x := random(n-1);
	    if not member(x, mon) then mon = append(mon, x);
	    );
	sort mon
	)
    )
scipPrintLevel = 0

for n in 5*toList(10..30) do(
    << "n = "<<n<<endl;
    R = QQ[x_1..x_n];
    I = monomialIdeal(apply(randomFixedDegreeMonomials(n, 20, 50), m -> product(apply(m, j -> R_j))));
    << "M2 dim " <<timing(dim I)<< endl;
    << "IP dim " <<timing(dimensionIP I)<< endl;
    )

for n in 5*toList(5..10) do(
    << "n = "<<n<<endl;
    R = QQ[x_1..x_n];
    I = monomialIdeal(apply(randomFixedDegreeMonomials(n, 20, 50), m -> product(apply(m, j -> R_j))));
    << "M2 deg " <<timing(degree I) << endl;
    << "IP deg " <<timing(degreeIP I) << endl;
    )