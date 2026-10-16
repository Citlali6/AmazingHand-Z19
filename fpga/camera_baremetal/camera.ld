/******************************************************************************
*
* Copyright (c) 2015 - 2020 Xilinx, Inc.  All rights reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/

/*******************************************************************/
/*                                                                 */
/* Description : A53 camera snapshot (adapted generated FSBL layout)                            */
/*                                                                 */
/*******************************************************************/
_STACK_SIZE = DEFINED(_STACK_SIZE) ? _STACK_SIZE : 0x2000;
_HEAP_SIZE = DEFINED(_HEAP_SIZE) ? _HEAP_SIZE : 1024;

/* Define Memories in the system */

MEMORY
{
 ddr : ORIGIN = 0x00100000, LENGTH = 0x07F00000
}

/* Specify the default entry point to the program */

ENTRY(_vector_table)

/* Define the sections, and where they are mapped in memory */

SECTIONS
{
.text : {
   KEEP (*(.vectors))
   *(.boot)
   *(.text)
   *(.text.*)
   *(.gnu.linkonce.t.*)
   *(.plt)
   *(.gnu_warning)
   *(.gcc_execpt_table)
   *(.glue_7)
   *(.glue_7t)
   *(.ARM.extab)
   *(.gnu.linkonce.armextab.*)
} > ddr

.note.gnu.build-id : {
   KEEP (*(.note.gnu.build-id))
} > ddr

.init (ALIGN(64)): {
   KEEP (*(.init))
} > ddr

.fini (ALIGN(64)): {
   KEEP (*(.fini))
} > ddr

.interp : {
   __interp_start = .;
   KEEP (*(.interp))
   __interp_end = .;
} > ddr

.note-ABI-tag : {
   __note-ABI-tag_start = .;
   KEEP (*(.note-ABI-tag))
   __note-ABI-tag_end = .;
} > ddr

.rodata (ALIGN(64)): {
   __rodata_start = .;
   *(.rodata)
   *(.rodata.*)
   *(.gnu.linkonce.r.*)
   __rodata_end = .;
} > ddr

.rodata1 (ALIGN(64)): {
   __rodata1_start = .;
   *(.rodata1)
   *(.rodata1.*)
   __rodata1_end = .;
} > ddr

.sys_cfg_data (ALIGN(64)): {
   *(.sys_cfg_data)
} > ddr

.eh_frame : {
  *(.eh_frame)
} > ddr

.eh_framehdr : {
   __eh_framehdr_start = .;
   *(.eh_framehdr)
   __eh_framehdr_end = .;
} > ddr

.gcc_except_table : {
   *(.gcc_except_table)
} > ddr

.mmu_tbl0 (ALIGN(4096)) : {
   __mmu_tbl0_start = .;
   *(.mmu_tbl0)
   __mmu_tbl0_end = .;
} > ddr

.mmu_tbl1 (ALIGN(4096)) : {
   __mmu_tbl1_start = .;
   *(.mmu_tbl1)
   __mmu_tbl1_end = .;
} > ddr

.mmu_tbl2 (ALIGN(4096)) : {
   __mmu_tbl2_start = .;
   *(.mmu_tbl2)
   __mmu_tbl2_end = .;
} > ddr

.data (ALIGN(64)): {
   __data_start = .;
   *(.data)
   *(.data.*)
   *(.gnu.linkonce.d.*)
   *(.jcr)
   *(.got)
   *(.got.plt)
   __data_end = .;
} > ddr

.data1 (ALIGN(64)): {
   __data1_start = .;
   *(.data1)
   *(.data1.*)
   __data1_end = .;
} > ddr

.tdata (ALIGN(64)): {
   __tdata_start = .;
   *(.tdata)
   *(.tdata.*)
   *(.gnu.linkonce.td.*)
   __tdata_end = .;
} > ddr

.got : {
   *(.got)
} > ddr

.got1 : {
   *(.got1)
} > ddr

.got2 : {
   *(.got2)
} > ddr
/*
.ctors (ALIGN(64)): {
   __CTOR_LIST__ = .;
   ___CTORS_LIST___ = .;
   KEEP (*crtbegin.o(.ctors))
   KEEP (*(EXCLUDE_FILE(*crtend.o) .ctors))
   KEEP (*(SORT(.ctors.*)))
   KEEP (*(.ctors))
   __CTOR_END__ = .;
   ___CTORS_END___ = .;
} > ddr
*/
/*
.dtors (ALIGN(64)): {
   __DTOR_LIST__ = .;
   ___DTORS_LIST___ = .;
   KEEP (*crtbegin.o(.dtors))
   KEEP (*(EXCLUDE_FILE(*crtend.o) .dtors))
   KEEP (*(SORT(.dtors.*)))
   KEEP (*(.dtors))
   __DTOR_END__ = .;
   ___DTORS_END___ = .;
} > ddr
*/
.fixup : {
   __fixup_start = .;
   *(.fixup)
   __fixup_end = .;
} > ddr

.ARM.exidx : {
   __exidx_start = .;
   *(.ARM.exidx*)
   *(.gnu.linkonce.armexidix.*.*)
   __exidx_end = .;
} > ddr

.preinit_array (ALIGN(64)): {
   __preinit_array_start = .;
   KEEP (*(SORT(.preinit_array.*)))
   KEEP (*(.preinit_array))
   __preinit_array_end = .;
} > ddr
/*
.init_array (ALIGN(64)): {
   __init_array_start = .;
   KEEP (*(SORT(.init_array.*)))
   KEEP (*(.init_array))
   __init_array_end = .;
} > ddr
*/
/*
.fini_array (ALIGN(64)): {
   __fini_array_start = .;
   KEEP (*(SORT(.fini_array.*)))
   KEEP (*(.fini_array))
   __fini_array_end = .;
} > ddr
*/
.ARM.attributes : {
   __ARM.attributes_start = .;
   *(.ARM.attributes)
   __ARM.attributes_end = .;
} > ddr

.sdata (ALIGN(64)): {
    __sdata_start = .;
   *(.sdata)
   *(.sdata.*)
   *(.gnu.linkonce.s.*)
   __sdata_end = .;
} > ddr

.sdata2 (ALIGN(64)): {
   __sdata2_start = .;
   *(.sdata2)
   *(.sdata2.*)
   *(.gnu.linkonce.s2.*)
   __sdata2_end = .;
} > ddr

.sbss (NOLOAD) : {
 . = ALIGN(64);
   __sbss_start = .;
   *(.sbss)
   *(.sbss.*)
   *(.gnu.linkonce.sb.*)
    . = ALIGN(64);
   __sbss_end = .;
} > ddr

.sbss2 (ALIGN(64)): {
   __sbss2_start = .;
   *(.sbss2)
   *(.sbss2.*)
   *(.gnu.linkonce.sb2.*)
   __sbss2_end = .;
} > ddr

.tbss (ALIGN(64)): {
   __tbss_start = .;
   *(.tbss)
   *(.tbss.*)
   *(.gnu.linkonce.tb.*)
   __tbss_end = .;
} > ddr

.bss (NOLOAD) : {
   . = ALIGN(64);
   __bss_start__ = .;
   *(.bss)
   *(.bss.*)
   *(.gnu.linkonce.b.*)
   *(COMMON)
   . = ALIGN(64);
   __bss_end__ = .;
} > ddr

_SDA_BASE_ = __sdata_start + ((__sbss_end - __sdata_start) / 2 );

_SDA2_BASE_ = __sdata2_start + ((__sbss2_end - __sdata2_start) / 2 );

/* Generate Stack and Heap definitions */

.heap (NOLOAD) : {
   . = ALIGN(64);
   _heap = .;
   HeapBase = .;
   _heap_start = .;
   . += _HEAP_SIZE;
   _heap_end = .;
   HeapLimit = .;
} > ddr

.stack (NOLOAD) : {
   . = ALIGN(64);
   _el3_stack_end = .;
   . += _STACK_SIZE;
   __el3_stack = .;
   __el2_stack = .;
   __el1_stack = .;
   __el0_stack = .;
} > ddr

_end = .;
}
