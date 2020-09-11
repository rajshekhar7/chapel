module analyze_RMAT_graph_associative_array {

  //
  // If graphInputFile != "", read in the graph from the files with
  // that prefix; do not run edge generation or Kernel 1.
  // Otherwise, if graphOutputFile != "" then write out the graph
  // generated by edge generation and Kernel 1 into those files.
  //
  // The *DStyle strings control the debugging printouts during I/O.
  // See interpretDStyle() for details.
  //
  // If graphVerifyFile != "" and the graph was read from graphInputFile,
  // write it out to graphVerifyFile. Could be used for correctness checking.
  //
  // The graph size in graphInputFile must match the SCALE config constant.
  //
  config const graphInputFile    = "";
  config const graphInputDStyle  = "-";
  config const graphOutputFile   = "";
  config const graphOutputDStyle = "-";
  config const graphVerifyFile   = "";
  config const graphVerifyDStyle = "-";

  // used during graph allocation
  config const initialRMATNeighborListLength =
    if graphInputFile == "" then 16 else 0;
  param initialFirstAvail = 1;

    //
    // We will represent the neighbor list as an array of nleType.
    // nle = Neighbor List Element.
    //
    type nleType = (int(64), int(64));
    // Extract each component from a neighbor.
    proc nleNID(nlElm: nleType)    return nlElm(0);
    proc nleWeight(nlElm: nleType) return nlElm(1);
    // Mark a use of a neighbor as a pair.
    proc nleAsPair(nlElm: nleType) return nlElm;
    // Produce a neighbor from components.
    proc nleMake(nID: int(64), wt: int(64)): nleType  return (nID, wt);

    //
    // VertexData: stores the neighbor list of a vertex.
    //
    record VertexData {
      var ndom = {initialFirstAvail..initialRMATNeighborListLength};
      var neighborList: [ndom] nleType;

      proc numNeighbors()  return ndom.size;

      // firstAvail$ must be passed by reference
      proc addEdgeOnVertex(uArg, vArg, wArg, firstAvail$: sync int) {
        on this do {
          // todo: the compiler should make these values local automatically!
          const /*u = uArg,*/ v = vArg, w = wArg;
            // Lock and unlock should be within 'local', but currently
            // need to pull them out due to implementation.
            // lock the vertex
            const edgePos = firstAvail$;

          local {
            const prevNdomLen = ndom.high;
            if edgePos > prevNdomLen {
              // grow our arrays, by 2x
              // statistics: growCount += 1;
              ndom = {1..prevNdomLen * 2};
              // bounds checking below will ensure (edgePos <= ndom.high)
            }
            // store the edge
            neighborList[edgePos] = nleMake(v, w);
          }

            // release the lock
            firstAvail$.writeEF(edgePos + 1);
        } // on
      }

      // not parallel-safe
      proc tidyNeighbors(firstAvail$: sync int) {
        local {
          // no synchronization here
          var edgeCount = firstAvail$.readXX() - 1;
          RemoveDuplicates(1, edgeCount);
          // TODO: ideally if we don't save much memory, do not resize
          if edgeCount != ndom.size {
            // statistics: shrinkCount += 1;
            ndom = 1..edgeCount;
          }
          // writeln("stats ", growCount, " ", shrinkCount, ".");
        }
      }

      //
      // Jargon: a "duplicate" is an edge v1->v2 for which
      // there is another edge v1->v2, possibly with a different weight.
      //
      proc RemoveDuplicates(lo, inout hi) {
        use IO;

        param showArrays = false;  // beware of 'local' in the caller
        const style = new iostyle(min_width_columns = 3);
        if showArrays {
          writeln("starting ", lo, "..", hi);
          stdout.writeln(neighborList(lo..hi), style);
        }

        // TODO: remove the duplicates as we sort
        // InsertionSort, keep duplicates
        for i in lo+1..hi {
          const (ithNID, ithEDW) = nleAsPair(neighborList(i));
          var inserted = false;

          for j in lo..i-1 by -1 {
            if ithNID < nleNID(neighborList(j)) {
              neighborList(j+1) = neighborList(j);
            } else {
              neighborList(j+1) = nleMake(ithNID, ithEDW);
              inserted = true;
              break;
            }
          }

          if (!inserted) {
            neighborList(lo)= nleMake(ithNID, ithEDW);
          }
        }
        //writeln("sorted ", lo, "..", hi);

        // remove the duplicates
        var foundDup = false;
        var indexDup: int;
        var lastNID = nleNID(neighborList(lo));

        for i in lo+1..hi {
          const currNID = nleNID(neighborList(i));
          if lastNID == currNID {
            foundDup = true;
            indexDup = i;
            break;
          } else {
            lastNID = currNID;
          }
        }

        if foundDup {
          // indexDup points to a hole
          // the already-found dup is dropped before entering the loop
          for i in indexDup+1..hi {
            const currNID = nleNID(neighborList(i));
            if lastNID == currNID {
              // dropping this duplicate
            } else {
              // moving a non-duplicate value
              neighborList(indexDup) = nleMake(currNID,
                                               nleWeight(neighborList(i)));
              indexDup += 1;
              lastNID = currNID;
            }
          }
          hi = indexDup - 1;
        }
        //writeln("eliminated dups ", lo, "..", hi);

        // VerifySort
        if boundsChecking then
          for i in lo..hi-1 do
            if !( nleNID(neighborList(i)) < nleNID(neighborList(i+1)) ) then
              writeln("unsorted IDs for i = ", i, "   ",
                      neighborList(i), " !< ", neighborList(i+1));

        if showArrays {
          writeln("sorted ", lo, "..", hi);
          stdout.writeln(neighborList(lo..hi), style);
          writeln();
        }
      }  // RemoveDuplicates


    } // record VertexData

  // +========================================================================+
  // |  Define associative array-based representations for general sparse     |
  // |  graphs. Provide execution template to generate a random RMAT graph    |
  // |  of a specified size and execute and verify SSCA2 kernels 2 through 4. |
  // =========================================================================+

  proc  generate_and_analyze_associative_array_RMAT_graph_representation {

    // -----------------------------------------------------------------
    // compute a random power law graph with 2^SCALE vertices, using 
    // the RMAT generator. Initially generate a list of triples. 
    // Then convert it to a Chapel representation of a sparse graph, 
    // timing this step (Kernel 1).  Finally, execute Kernels 2, 3 and 4
    // of SSCA #2, using identically the same code as in the various
    // torus cases.
    // -----------------------------------------------------------------

    use SSCA2_compilation_config_params, SSCA2_execution_config_consts;
  
    use SSCA2_driver, SSCA2_RMAT_graph_generator;

    use BlockDist;

    use io_RMAT_graph;

    var n_raw_edges = 8 * N_VERTICES;

    assert ( SCALE > 1, "SCALE must be greater than 1");

    select SCALE {
      when 2 do n_raw_edges = N_VERTICES / 2;
      when 3 do n_raw_edges = N_VERTICES;
      when 4 do n_raw_edges = 2 * N_VERTICES;
      when 5 do n_raw_edges = 4 * N_VERTICES;
      }

    writeln ('-------------------------------------');
    writeln ('Order of RMAT generated graph:', N_VERTICES);
    writeln ('          number of raw edges:', n_raw_edges);
    writeln ('-------------------------------------');
    writeln ();

    // ------------------------------------------------------------------------
    // The data structures below are chosen to implement an irregular (sparse)
    // graph using rectangular domains and arrays.  
    // Each node in the graph has a list of neighbors and a corresponding list
    // of (integer) weights for the implicit edges.  
    // ------------------------------------------------------------------------

    const vertex_domain = 
      if DISTRIBUTION_TYPE == "BLOCK" then
        {1..N_VERTICES} dmapped Block ( {1..N_VERTICES} )
      else
    {1..N_VERTICES} ;
	
    class Associative_Graph {
      const vertices;
      var   Row      : [vertices] VertexData;
      var num_edges = -1;

      // iterate over neighbor IDs, with filtering

      iter FilteredNeighbors( v : index (vertices) ) {
        for nlElm in Row(v).neighborList do
          if !FILTERING || nleWeight(nlElm)%8 != 0 then
            yield nleNID(nlElm);
      }

      iter FilteredNeighbors( v : index (vertices), param tag: iterKind)
      where tag == iterKind.standalone {
        const ref neighbors = Row(v).neighborList;
        // 1-d, no stride
        forall n in Row(v).ndom {
          if !FILTERING || nleWeight(neighbors(n))%8 != 0 then
            yield nleNID(neighbors(n));
        }
      }

      // iterate over all neighbor (ID, weight) pairs

      proc NeighborPairs( v : index (vertices) ) ref {   // implies nleAsPair
        return Row (v).neighborList;
      }

      // iterate over all neighbor IDs

      iter Neighbors( v : index (vertices) ) {
        for nlElm in Row(v).neighborList do
          yield nleNID(nlElm);
      }

      iter Neighbors( v : index (vertices), param tag: iterKind)
      where tag == iterKind.standalone {
        forall nlElm in Row(v).neighborList do
          yield nleNID(nlElm);
      }

      // iterate over all neighbor weights

      iter edge_weight( v : index (vertices) ) {
        for nlElm in Row(v).neighborList do
          yield nleWeight(nlElm);
      }

      iter edge_weight( v : index (vertices), param tag: iterKind)
      where tag == iterKind.standalone {
        for nlElm in Row(v).neighborList do
          yield nleWeight(nlElm);
      }

      // return the number of all neighbors

      proc   n_Neighbors (v : index (vertices) ) 
      {return Row (v).numNeighbors();}

    } // class Associative_Graph

    writeln("allocating Associative_Graph");
    var G = new unmanaged Associative_Graph (vertex_domain);

    // ------------------------------------------------------------------
    // generate RMAT graph of the specified size, based on input config
    // values for quadrant assignment.
    // ------------------------------------------------------------------

   if graphInputFile == "" {
    Gen_RMAT_graph ( RMAT_a, RMAT_b, RMAT_c, RMAT_d, vertex_domain,
		     SCALE, N_VERTICES, n_raw_edges, MAX_EDGE_WEIGHT, G ); 

    if graphOutputFile != "" then
      Writeout_RMAT_graph ( G, graphOutputFile, graphOutputDStyle );

   } else {
    Readin_RMAT_graph ( G, graphInputFile, graphInputDStyle );

    if graphVerifyFile != "" then
      Writeout_RMAT_graph ( G, graphVerifyFile, graphVerifyDStyle );
   }

    execute_SSCA2 ( G );
    writeln (); writeln ();
    delete G;
  }

}
