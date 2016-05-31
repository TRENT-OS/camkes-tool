/*#
 *# Copyright 2015, NICTA
 *#
 *# This software may be distributed and modified according to the terms of
 *# the BSD 2-Clause license. Note that NO WARRANTY is provided.
 *# See "LICENSE_BSD2.txt" for details.
 *#
 *# @TAG(NICTA_BSD)
 #*/

/*- if len(me.parent.from_ends) != 1 -*/
  /*? raise(TemplateError('connections without a single from end are not supported', me.parent)) ?*/
/*- endif -*/

/*- set thy = os.path.splitext(os.path.basename(options.outfile.name))[0] -*/
(*<*)
theory "/*? thy ?*/" imports
  "~~/../l4v/tools/c-parser/CTranslation"
  "~~/../l4v/tools/autocorres/AutoCorres"
  "~~/../l4v/tools/autocorres/NonDetMonadEx"
begin

(* THIS THEORY IS GENERATED. DO NOT EDIT.
 * It is expected to be hosted in l4v/camkes/glue-proofs.
 *)

declare [[allow_underscore_idents=true]]

install_C_file "/*? thy ?*/_seL4RPCSimple_pruned.c_pp"

(* Use non-determinism instead of the standard option monad type stregthening and do not heap
 * abstract seL4_SetMR.
 *)
autocorres [ts_rules = nondet, no_heap_abs = seL4_SetMR] "/*? thy ?*/_seL4RPCSimple_pruned.c_pp"

context "/*? thy ?*/_seL4RPCSimple_pruned" begin

(* Introduce this definition here so we can refer to it in the locale extension below. *)
definition
  seL4_SetMR_lifted' :: "int \<Rightarrow> word32 \<Rightarrow> lifted_globals \<Rightarrow> (unit \<times> lifted_globals) set \<times> bool"
where
  "seL4_SetMR_lifted' i val \<equiv>
   do
     ret' \<leftarrow> seL4_GetIPCBuffer';
     guard (\<lambda>s. i < uint seL4_MsgMaxLength);
     guard (\<lambda>s. 0 \<le> i);
     modify (\<lambda>s. s \<lparr>heap_seL4_IPCBuffer__C :=
       (heap_seL4_IPCBuffer__C s)(ret' :=
          msg_C_update (\<lambda>a. Arrays.update a (nat i) val)
             (heap_seL4_IPCBuffer__C s ret'))
     \<rparr>)
  od"

end

locale "/*? thy ?*/_seL4RPCSimple_glue" = "/*? thy ?*/_seL4RPCSimple_pruned" +
  assumes seL4_SetMR_axiom: "exec_concrete lift_global_heap (seL4_SetMR' i val) = seL4_SetMR_lifted' i val"
begin
(*>*)

chapter {* Assumptions *}

text {*
  This chapter introduces some definitions for properties that we assume to be invariant across the
  execution of user code. That is, the glue code lemmas in chapters that follow contain explicit
  assumptions that the user code in a component preserves the properties given below.

  Threads in seL4 communicate with one another via an Inter-Process Communication (IPC) mechanism
  provided by the kernel. Each thread has an assigned IPC buffer, a region of memory in their
  address space, that is taken by the kernel as an implicit parameter to any syscall. In an IPC
  message that involves communication with another thread, the sender writes the transfer payload
  to their IPC buffer before syscall invocation. CAmkES leverages this communication mechanism in
  implementing its own primitives.

  In seL4, the globals frame is a single page mapped read-only to userspace, whose first word
  contains a pointer to the current thread's IPC buffer. The CAmkES glue code uses this to marshal
  RPC arguments in to and out of the IPC buffer. For the glue code's operations to be valid, we
  require the globals frame not to have been modified. We create the following two definitions as
  shorthands for the globals frame still containing a valid pointer to the IPC buffer and the
  pointed to buffer still being valid, typed memory, respectively.
*}
definition
  globals_frame_intact :: "lifted_globals \<Rightarrow> bool"
where
  "globals_frame_intact s \<equiv>
    is_valid_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame))"

definition
  ipc_buffer_valid :: "lifted_globals \<Rightarrow> bool"
where
  "ipc_buffer_valid s \<equiv> is_valid_seL4_IPCBuffer__C s
    (heap_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame)))"

text {*
  One of the underlying tools we rely on does not currently fully abstract writes to arrays within
  structs. The glue code performs such operations when writing to threads' IPC buffers, in the
  function \code{seL4\_SetMR}. In order to work with a fully abstracted representation of these writes, we
  provide the following abstract definition of the function and axiomatise its equivalence to the
  partially abstracted representation we have. In future this axiomatisation will be removed and the
  abstraction framework will emit the definition below and an accompanying proof of equivalence in
  place of the axiom.
*}
text {* \newpage *}
(* We repeat this definition because Isabelle's rendering of the original back to us via @{thm ...}
 * does not get formatted nicely. We use a different name in order not to interfere with any
 * following lemmas. Hopefully it won't confuse the reader.
 *)
definition
  seL4_SetMR_lifted
where
  "seL4_SetMR_lifted i val \<equiv>
     do
       ret' \<leftarrow> seL4_GetIPCBuffer';
       guard (\<lambda>s. i < uint seL4_MsgMaxLength);
       guard (\<lambda>s. 0 \<le> i);
       modify (\<lambda>s. s \<lparr>heap_seL4_IPCBuffer__C :=
         (heap_seL4_IPCBuffer__C s)(ret' :=
            msg_C_update (\<lambda>a. Arrays.update a (nat i) val)
               (heap_seL4_IPCBuffer__C s ret'))
       \<rparr>)
    od"

text {*
  The number of threads in a CAmkES component is dependent on the incoming and outgoing interfaces
  to that component. Per-thread data is generated as part of the connector glue code, including
  thread-local storage (TLS) variables. These variables are accessed via the current thread's TLS
  region. The following definitions are later used to express assumptions that the TLS region of
  the current thread has not been modified by intervening user code. In practice, non-malicious user
  code should never modify the TLS region or any thread-local variables.
*}
definition
  tls_ptr :: "lifted_globals \<Rightarrow> camkes_tls_t_C ptr"
where
  "tls_ptr s \<equiv> Ptr (ptr_val (heap_seL4_IPCBuffer__C'ptr s
     (Ptr (scast seL4_GlobalsFrame))) && 0xFFFFF000)"

definition
  tls :: "lifted_globals \<Rightarrow> camkes_tls_t_C"
where
  "tls s \<equiv> heap_camkes_tls_t_C s (tls_ptr s)"

definition
  tls_valid :: "lifted_globals \<Rightarrow> bool"
where
  "tls_valid s \<equiv> is_valid_camkes_tls_t_C s (tls_ptr s)"

text {*
  We make a further assumption about the execution of the kernel on behalf of a user thread that is
  explained in the next chapter.
*}

chapter {* System Calls *}

text {*
  A thread's IPC buffer contains a number of message registers that are used for transferring data
  during an IPC operation. The following two definitions are used to abbreviate the operation of
  setting a specific message register and setting the first four message registers, respectively.
  We have a specific definition for setting the first four message registers because this is a
  common operation performed by the seL4 syscall stubs (user-level kernel entry utility functions).
*}
definition
  setMR :: "lifted_globals \<Rightarrow> nat \<Rightarrow> word32 \<Rightarrow> lifted_globals"
where
  "setMR s i v \<equiv>
      s\<lparr>heap_seL4_IPCBuffer__C := (heap_seL4_IPCBuffer__C s)
        (heap_seL4_IPCBuffer__C'ptr s (Ptr (scast seL4_GlobalsFrame)) :=
          msg_C_update (\<lambda>a. Arrays.update a i v)
            (heap_seL4_IPCBuffer__C s (heap_seL4_IPCBuffer__C'ptr s
              (Ptr (scast seL4_GlobalsFrame)))))\<rparr>"

definition
  setMRs :: "lifted_globals \<Rightarrow> word32 \<Rightarrow> word32 \<Rightarrow>
             word32 \<Rightarrow> word32 \<Rightarrow> lifted_globals"
where
  "setMRs s mr0 mr1 mr2 mr3 \<equiv>
    setMR (setMR (setMR (setMR s 0 mr0) 1 mr1) 2 mr2) 3 mr3"

text {*
  Before showing properties of the syscall stubs, we introduce some lemmas specifying the effect
  of some seL4 supporting functions. The function \code{seL4\_GetIPCBuffer} returns a pointer to
  the current thread's IPC buffer, while the functions \code{seL4\_SetMR} and \code{seL4\_GetMR}
  write to and read from the message registers of the IPC buffer, respectively. The following
  lemmas state their effects, and are used below in reasoning about the effect of the syscall stubs
  themselves.

  Some of these are tagged ``[wp\_unsafe],'' which allows the wp tactic to hint to an
  interactive user when it could have made further progress with this lemma available. These tags
  are included for convenience when adapting or exploring a generated proof. The optional ``notes''
  header of a lemma allows existing lemmas to be modified for the duration of the current proof.
  The \code{seL4\_SetMR} proof uses this to make the axiom we discussed previously available to
  Isabelle's simp tactic.
*}
text {* \newpage *}
lemma seL4_GetIPCBuffer_wp':
  "\<forall>s'. \<lbrace>\<lambda>s. globals_frame_intact s \<and>
             s = s'\<rbrace>
         seL4_GetIPCBuffer'
        \<lbrace>\<lambda>r s. r = heap_seL4_IPCBuffer__C'ptr s
                 (Ptr (scast seL4_GlobalsFrame)) \<and>
               s = s'\<rbrace>!"
  apply (rule allI)
  apply (simp add:seL4_GetIPCBuffer'_def)
  apply wp
  apply (clarsimp simp:globals_frame_intact_def)
  done

(*<*)
lemmas seL4_GetIPCBuffer_wp[wp_unsafe] =
  seL4_GetIPCBuffer_wp'[THEN validNF_make_schematic_post, simplified]
(*>*)

lemma seL4_SetMR_wp[wp_unsafe]:
  notes seL4_SetMR_axiom[simp]
  shows
  "\<lbrace>\<lambda>s. globals_frame_intact s \<and>
        ipc_buffer_valid s \<and>
        i \<ge> 0 \<and>
        i < uint seL4_MsgMaxLength \<and>
        (\<forall>x. P x (setMR s (nat i) v))\<rbrace>
    exec_concrete lift_global_heap (seL4_SetMR' i v)
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_SetMR_lifted'_def)
  apply (wp seL4_GetIPCBuffer_wp)
  apply (simp add:setMR_def globals_frame_intact_def ipc_buffer_valid_def)
  done

lemma seL4_GetMR_wp[wp_unsafe]:
  "\<lbrace>\<lambda>s. \<forall>x. i \<ge> 0 \<and>
            i < uint seL4_MsgMaxLength \<and>
            globals_frame_intact s \<and>
            ipc_buffer_valid s \<and>
            P x s\<rbrace>
    seL4_GetMR' i
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_GetMR'_def)
  apply (wp seL4_GetIPCBuffer_wp)
  apply (simp add:globals_frame_intact_def ipc_buffer_valid_def seL4_MsgMaxLength_def)
  done

text {*
  The C standard library provides a function, \code{abort}, that is called by
  the CAmkES glue code in the event of an unrecoverable error. We do not
  provide a definition of the function itself and instead use the following
  lemma to later prove that all invocations to \code{abort} are dead code that
  is never executed.
*}
lemma abort_wp[wp]:
  "\<lbrace>\<lambda>_. False\<rbrace> abort' \<lbrace>P\<rbrace>!"
  by (rule validNF_false_pre)

text {*
  We now introduce lemmas specifying the behaviour of seL4 syscall stubs. These functions write
  syscall arguments into hardware registers, perform an assembly instruction to enter the kernel
  and then unpack the kernel's response. The following lemmas express that these invocations can
  never fail. We only provide lemmas for the syscalls used by the CAmkES glue code.
*}
lemma seL4_Call_wp[wp_unsafe]:
  notes seL4_SetMR_wp[wp] seL4_GetMR_wp[wp]
  shows
  "\<lbrace>\<lambda>s. globals_frame_intact s \<and>
        ipc_buffer_valid s \<and>
        (\<forall>x v0 v1 v2 v3. P x (setMRs s v0 v1 v2 v3))\<rbrace>
    seL4_Call' cap info
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_Call'_def)
  apply wp
  apply (simp add:globals_frame_intact_def ipc_buffer_valid_def setMRs_def
                  setMR_def seL4_MsgMaxLength_def)
  done
(* The remaining syscall WP lemmas are irrelevant for the proofs in this locale, but we prove them
 * here so they appear in a logical location if we're building a document.
 *)
lemma seL4_Notify_wp[wp_unsafe]:
  "\<lbrace>\<lambda>s. \<forall>x. P x s\<rbrace>
    seL4_Notify' cap data
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_Notify'_def seL4_MessageInfo_new'_def)
  apply wp
  apply simp
  done

lemma seL4_Poll_wp[wp_unsafe]:
  "\<lbrace>\<lambda>s. globals_frame_intact s \<and>
        ipc_buffer_valid s \<and>
        (\<forall>x b v0 v1 v2 v3. P x (heap_w32_update
          (\<lambda>a. a(badge := b)) (setMRs s v0 v1 v2 v3))) \<and>
        badge \<noteq> NULL \<and>
        is_valid_w32 s badge\<rbrace>
    seL4_Poll' cap badge
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_Poll'_def seL4_GetIPCBuffer'_def)
  apply (wp seL4_SetMR_wp)
  apply (simp add:globals_frame_intact_def ipc_buffer_valid_def setMRs_def
                  setMR_def seL4_MsgMaxLength_def)
  done

text {* \newpage *}
lemma seL4_ReplyWait_wp[wp_unsafe]:
  "\<lbrace>\<lambda>s. globals_frame_intact s \<and>
        ipc_buffer_valid s \<and>
        (\<forall>x v0 v1 v2 v3. P x (setMRs s v0 v1 v2 v3))\<rbrace>
    seL4_ReplyWait' cap info NULL
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_ReplyWait'_def seL4_GetMR'_def)
  apply (wp seL4_SetMR_wp seL4_GetIPCBuffer_wp)
  apply (simp add:globals_frame_intact_def ipc_buffer_valid_def setMRs_def
                  setMR_def seL4_MsgMaxLength_def)
  done

lemma seL4_Wait_wp[wp_unsafe]:
  "\<lbrace>\<lambda>s. globals_frame_intact s \<and>
        ipc_buffer_valid s \<and>
        (\<forall>x v0 v1 v2 v3. P x (setMRs s v0 v1 v2 v3))\<rbrace>
    seL4_Wait' cap NULL
   \<lbrace>P\<rbrace>!"
  apply (simp add:seL4_Wait'_def)
  apply (wp seL4_SetMR_wp)
  apply (simp add:globals_frame_intact_def ipc_buffer_valid_def setMRs_def
                  setMR_def seL4_MsgMaxLength_def)
  done

text {*
  It should be noted that each of these proofs about a system call stub implicitly assumes that the
  execution of the kernel itself has no effect on the user state. Obviously this is not true in
  practice or components would not be able to communicate via IPC. For now, the actual behaviour of
  the kernel is not required to show safe execution of the glue code. Further functional
  correctness proofs in future will involve a semantics of the kernel's execution and its effect on
  the user state.
*}

(*<*)
/*- set threads = 1 + len(me.instance.type.provides + me.instance.type.uses + me.instance.type.emits + me.instance.type.consumes + me.instance.type.dataports) -*/
definition
  thread_count :: word32
where
  "thread_count \<equiv> /*? threads ?*/"

(* Any array parameters will have caused a TLS array to be generated. Prove a WP lemma for each
 * here.
 *)
/*- for m in me.interface.type.methods -*/
/*- for p in m.parameters -*/
/*- if p.array -*/
(** TPP: condense = True *)
lemma get_/*? m.name ?*/_/*? p.name ?*/_wp[wp_unsafe]:
  /*- set state = isabelle_symbol('s') -*/
  "\<lbrace>\<lambda>/*? state ?*/. globals_frame_intact /*? state ?*/ \<and>
        ipc_buffer_valid /*? state ?*/ \<and>
        tls_valid /*? state ?*/ \<and>
        thread_index_C (tls /*? state ?*/) \<in> {1..thread_count} \<and>
        /*- for t in six.moves.range(threads) -*/
          is_valid_w/*? macros.sizeof(options.architecture, p) * 8 ?*/'ptr /*? state ?*/ (Ptr (symbol_table ''/*? m.name ?*/_/*? p.name ?*/_ptr_/*? t + 1 ?*/'')) \<and>
        /*- endfor -*/
        /*# Somewhat awkward. We need to know whether the type of the members of this array is
         *# signed or unsigned. Although both signed and unsigned types are consolidated (per
         *# width) in a single heap, pointers to pointers still end up showing the signedness of
         *# the underlying value. We need to use this to constrain the following bound variable or
         *# it does not correctly unify with a later subgoal.
         #*/
        /*- if p.type in ['int', 'int8_t', 'int16_t', 'int32_t', 'int64_t'] -*/
            /*- set word_type = 'sword' -*/
        /*- else -*/
            /*- set word_type = 'word' -*/
        /*- endif -*/
        /*- for t in six.moves.range(threads) -*/
          (\<forall>(a :: /*? word_type ?*//*? macros.sizeof(options.architecture, p) * 8 ?*/ ptr)\<in>set (array_addrs (Ptr (symbol_table ''/*? m.name ?*/_/*? p.name ?*/_/*? t + 1 ?*/'')) (uint seL4_MsgMaxLength)). is_valid_w/*? macros.sizeof(options.architecture, p) * 8 ?*/ /*? state ?*/ (ptr_coerce a)) \<and>
        /*- endfor -*/
        /*- for t in six.moves.range(threads) -*/
(** TPP: accumulate = True *)
          (\<forall>x. P x (heap_w/*? macros.sizeof(options.architecture, p) * 8 ?*/'ptr_update (\<lambda>x. x(Ptr (symbol_table ''/*? m.name ?*/_/*? p.name ?*/_ptr_/*? t + 1 ?*/'') := Ptr (symbol_table ''/*? m.name ?*/_/*? p.name ?*/_/*? t + 1 ?*/''))) /*? state ?*/))
          /*- if not loop.last -*/
            \<and>
          /*- endif -*/
(** TPP: accumulate = False *)
        /*- endfor -*/
   \<rbrace>
    get_/*? m.name ?*/_/*? p.name ?*/'
   \<lbrace>P\<rbrace>!"
  apply (simp add:get_/*? m.name ?*/_/*? p.name ?*/'_def camkes_get_tls'_def)
  apply (wp seL4_GetIPCBuffer_wp)
  apply (clarsimp simp:globals_frame_intact_def ipc_buffer_valid_def tls_def tls_ptr_def
                       tls_valid_def thread_count_def)
  apply unat_arith
  done
(** TPP: condense = False *)
/*- endif -*/
/*- endfor -*/
/*- endfor -*/
(*>*)

chapter {* RPC Send *}
(*<*)
(* This lemma captures the safety of the /*? me.interface.name ?*/__run function
 * which is invoked on startup in this glue code. It is excluded from the final document because
 * the function itself is trivial and the proof uninteresting.
 *)
lemma /*? me.interface.name ?*/_run_nf: "\<lbrace>\<lambda>s. \<forall>r. P r s\<rbrace> /*? thy ?*/__run' \<lbrace>P\<rbrace>!"
  apply (simp add: /*? thy ?*/__run'_def)
  apply wp
  apply simp
  done
(*>*)

text {*
  Having introduced supporting lemmas, we are now in a position to express the safety of the CAmkES
  glue code itself. The lemmas and proofs in this chapter are generated from the following CAmkES
  interface definition:
  \camkeslisting{simple.camkes}
  This describes a CAmkES procedural interface containing six methods. To give some idea of what
  the code for this procedure looks like, the generated implementation of the first method follows.
  \clisting{from-echo-int.c}

  We generate a proof for each
  method that the generated glue code does not fail. The purpose of these six is to
  demonstrate that proof generation generalises across the various CAmkES data types and
  parameter combinations. The same generation logic produces a proof for word-sized parameters
  (e.g. \code{int}), parameters smaller than a word (e.g. \code{char}) and parameters greater than
  a word (e.g. \code{uint64\_t}). Similarly the generation logic handles input, output and
  bidirectional parameters, as well as methods with and without a return value.

  The proofs themselves state that the glue code obeys the C99 standard and that, when invoked, it
  consistently terminates (returns to the user) and does not reference invalid memory. The
  assumptions are the properties of the globals frame and TLS region discussed previously and,
  where relevant, that any pointers passed to the glue code can be safely dereferenced.
*}
/*- for m in me.interface.type.methods -*/
/*- if m.name in ['echo_char', 'increment_parameter'] -*/
    text {* \newpage *}
/*- endif -*/
(** TPP: condense = True *)
/*- set state = isabelle_symbol('s') -*/
lemma /*? me.interface.name ?*/_/*? m.name ?*/_nf:
  notes seL4_SetMR_wp[wp] seL4_GetMR_wp[wp]
  shows
  "\<lbrace>\<lambda>/*? state ?*/. globals_frame_intact /*? state ?*/ \<and>
(** TPP: lock_indent = 5 + len("/*? state ?*/") + 2 *)

  /*# Any 'out' or 'inout' parameters are passed to us as valid pointers. #*/
  /*- for p in m.parameters -*/
    /*- if p.direction in ['out', 'inout'] -*/
      /*- set size = macros.sizeof(options.architecture, p) -*/
      /*# The size must be something AutoCorres can handle. #*/
      /*? assert(size in [1, 2, 4, 8]) ?*/
      is_valid_w/*? size * 8 ?*/ /*? state ?*/ (ptr_coerce /*? p.name ?*/) \<and>
    /*- endif -*/
  /*- endfor -*/

      ipc_buffer_valid /*? state ?*/\<rbrace>
(** TPP: lock_indent = None *)

(** TPP: accumulate = True *)
    /*# The name of the function as translated into Isabelle. #*/
   /*? me.interface.name ?*/_/*? m.name ?*/'

    /*# The function's parameters. #*/
    /*- for p in m.parameters -*/
        /*? p.name ?*/
    /*- endfor -*/
(** TPP: accumulate = False *)

  \<lbrace>\<lambda>_ /*? state ?*/. globals_frame_intact /*? state ?*/ \<and>
(** TPP: lock_indent = 6 + len("/*? state ?*/") + 2 *)

  /*# Any 'out' or 'inout' parameter pointers are still valid. #*/
  /*- for p in m.parameters -*/
    /*- if p.direction in ['out', 'inout'] -*/
      /*- set size = macros.sizeof(options.architecture, p) -*/
      /*# The size must be something AutoCorres can handle. #*/
      /*? assert(size in [1, 2, 4, 8]) ?*/
      is_valid_w/*? size * 8 ?*/ /*? state ?*/ (ptr_coerce /*? p.name ?*/) \<and>
    /*- endif -*/
  /*- endfor -*/

     ipc_buffer_valid /*? state ?*/\<rbrace>!"
(** TPP: lock_indent = None *)
  apply (simp add:/*? me.interface.name ?*/_/*? m.name ?*/'_def /*? me.interface.name ?*/_/*? m.name ?*/_marshal'_def
                  /*? me.interface.name ?*/_/*? m.name ?*/_call'_def /*? me.interface.name ?*/_/*? m.name ?*/_unmarshal'_def)
  apply (wp seL4_Call_wp)
    apply (simp add:seL4_MessageInfo_new'_def)
    apply wp
  apply (simp add:globals_frame_intact_def ipc_buffer_valid_def
                  setMRs_def setMR_def seL4_MsgMaxLength_def)
  done
(** TPP: condense = False *)
/*- endfor -*/

(*<*)
end

end
(*>*)
