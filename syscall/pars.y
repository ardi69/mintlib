/*
 * This file belongs to FreeMiNT. It's not in the original MiNT 1.12
 * distribution. See the file CHANGES for a detailed log of changes.
 * 
 * 
 * Copyright 2000, 2001, 2002 Frank Naumann <fnaumann@freemint.de>
 * All rights reserved.
 * 
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 * 
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 * 
 * 
 * begin:	2000-01-01
 * last change:	2000-03-07
 * 
 * Author:	Frank Naumann <fnaumann@freemint.de>
 * 
 * Please send suggestions, patches or bug reports to me or
 * the MiNT mailing list.
 * 
 * 
 * changes since last version:
 * 
 * known bugs:
 * 
 * todo:
 * 
 * optimizations:
 * 
 */

%{

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "list.h"

/* prototypes */
void yyerror(char *s);

/* from scanner */
int yylex (void);
extern int yylinecount;
extern char *yytext;

extern int errors;

#define OUT_OF_MEM(x) \
	if (!x) \
	{ yyerror("out of memory"); YYERROR; }

static void
insert_string(char *dst, const char *src)
{
	char save[STRMAX];
	int l;
	
	strcpy(save, dst);
	strcpy(dst, src);
	
	l = strlen(dst);
	dst[l++] = ' ';
	strcpy(dst+l, save);
}

/* local variable */
SYSTAB *tab = NULL;

%}

%union {
	/* terminals */
	char	ident[STRMAX];
	long	value;
	
	/* nonterminals */
	SYSTAB	*tab;
	LIST	*list;
}

%token	<ident>	_IDENT_DOS
%token	<ident>	_IDENT_BIOS
%token	<ident>	_IDENT_XBIOS
%token	<ident>	_IDENT_RESERVED
%token	<ident>	_IDENT_NULL
%token	<ident>	_IDENT_MAX

%token	<ident>	_IDENT_VOID
%token	<ident>	_IDENT_CONST
%token	<ident>	_IDENT_STRUCT
%token	<ident>	_IDENT_UNION

%token	<ident>	_IDENT_CHAR
%token	<ident>	_IDENT_SHORT
%token	<ident>	_IDENT_LONG
%token	<ident>	_IDENT_UNSIGNED
%token	<ident>	_IDENT_UCHAR
%token	<ident>	_IDENT_USHORT
%token	<ident>	_IDENT_ULONG

%token	<ident>	Identifier
%token	<value>	Integer


%type	<tab>	dos
%type	<tab>	bios
%type	<tab>	xbios

%type	<list>	parameter_list
%type	<list>	simple_parameter_list
%type	<list>	simple_parameter
%type	<list>	simple_type
%type	<list>	type


%start syscalls

%%

syscalls
:	dos bios xbios
	{
		DOS = $1;
		BIOS = $2;
		XBIOS = $3;
	}
;

dos
:	{
		tab = malloc(sizeof(*tab));
		OUT_OF_MEM(tab);
		
		bzero (tab, sizeof(*tab));
		
		tab->size = INITIAL_DOS;
		tab->table = malloc(tab->size * sizeof(*(tab->table)));
		OUT_OF_MEM(tab->table);
		
		bzero (tab->table, tab->size * sizeof(*(tab->table)));
	}
	'[' _IDENT_DOS ']' definition_list
	{
		$$ = tab;
	}
;

bios
:	{
		tab = malloc(sizeof(*tab));
		OUT_OF_MEM(tab);
		
		bzero (tab, sizeof(*tab));
		
		tab->size = INITIAL_BIOS;
		tab->table = malloc(tab->size * sizeof(*(tab->table)));
		OUT_OF_MEM(tab->table);
		
		bzero (tab->table, tab->size * sizeof(*(tab->table)));
	}
	'[' _IDENT_BIOS ']' definition_list
	{
		$$ = tab;
	}
;

xbios
:	{
		tab = malloc(sizeof(*tab));
		OUT_OF_MEM(tab);
		
		bzero(tab, sizeof(*tab));
		
		tab->size = INITIAL_XBIOS;
		tab->table = malloc(tab->size * sizeof(*(tab->table)));
		OUT_OF_MEM(tab->table);
		
		bzero (tab->table, tab->size * sizeof(*(tab->table)));
	}
	'[' _IDENT_XBIOS ']' definition_list
	{
		$$ = tab;
	}
;

definition_list
:	definition
	{ }
|	definition_list definition
	{ }
;

definition
:	Integer Identifier Identifier '(' parameter_list ')'
	{
		if (tab->max && $1 >= tab->max)
		{ yyerror("entry greater than MAX"); YYERROR; }
		
		if (add_tab(tab, $1, $2[0], $3, $5))
		{ yyerror("out of memory"); YYERROR; }
	}
|	Integer _IDENT_NULL
	{
		if (tab->max && $1 >= tab->max)
		{ yyerror("entry greater than MAX"); YYERROR; }
		
		if (add_tab(tab, $1, 0, NULL, NULL))
		{ yyerror("out of memory"); YYERROR; }
	}
|	Integer _IDENT_RESERVED
	{
		if (tab->max && $1 >= tab->max)
		{ yyerror("entry greater than MAX"); YYERROR; }
		
		if (add_tab(tab, $1, 0, $2, NULL))
		{ yyerror("out of memory"); YYERROR; }
	}
|	Integer _IDENT_MAX
	{
		if (tab->max)
		{ yyerror("MAX already defined"); YYERROR; }
		
		tab->max = $1;
		
		if (tab->maxused && tab->maxused >= tab->max)
		{ yyerror("there are entries greater than MAX"); YYERROR; }
		
		if (!resize_tab(tab, tab->max))
		{ yyerror("out of memory"); YYERROR; }
	}
;

parameter_list
:	_IDENT_VOID
	{
		$$ = NULL;
	}
|	simple_parameter_list
	{
		$$ = $1;
	}
;

simple_parameter_list
:	simple_parameter
	{
		LIST *l = $1;
		
		$$ = l;
	}
|	simple_parameter_list ',' simple_parameter
	{
		LIST *head = $1;
		LIST *l = $3;
		
		add_list(&(head->next), l);
		
		$$ = head;
	}
;

simple_parameter
:	simple_type Identifier
	{
		LIST *l = $1;
		
		strcpy(l->name, $2);
		
		$$ = l;
	}
|	simple_type '*' Identifier
	{
		LIST *l = $1;
		
		strcpy(l->name, $3);
		l->flags |= FLAG_POINTER;
		
		$$ = l;
	}
|	simple_type Identifier '[' ']'
	{
		LIST *l = $1;
		
		strcpy(l->name, $2);
		l->flags |= FLAG_POINTER;
		
		$$ = l;
	}
|	simple_type Identifier '[' Integer ']'
	{
		LIST *l = $1;
		
		strcpy(l->name, $2);
		l->flags |= FLAG_ARRAY;
		l->ar_size = $4;
		
		$$ = l;
	}
;

simple_type
:	type
	{
		LIST *l = $1;
		
		$$ = l;
	}
|	_IDENT_CONST type
	{
		LIST *l = $2;
		
		l->flags |= FLAG_CONST;
		// insert_string(l->types, $1);
		
		$$ = l;
	}
|	_IDENT_STRUCT type
	{
		LIST *l = $2;
		
		l->flags |= FLAG_STRUCT;
		insert_string(l->types, $1);
		
		$$ = l;
	}
|	_IDENT_CONST _IDENT_STRUCT type
	{
		LIST *l = $3;
		
		l->flags |= FLAG_CONST;
		l->flags |= FLAG_STRUCT;
		insert_string(l->types, $2);
		// insert_string(l->types, $1);
		
		$$ = l;
	}
|	_IDENT_UNION type
	{
		LIST *l = $2;
		
		l->flags |= FLAG_UNION;
		insert_string(l->types, $1);
		
		$$ = l;
	}
;

type
:	_IDENT_CHAR
	{
		LIST *l;
		
		l = make_list(TYPE_CHAR, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	_IDENT_SHORT
	{
		LIST *l;
		
		l = make_list(TYPE_SHORT, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	_IDENT_LONG
	{
		LIST *l;
		
		l = make_list(TYPE_LONG, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	_IDENT_UNSIGNED
	{
		LIST *l;
		
		l = make_list(TYPE_UNSIGNED, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	_IDENT_UCHAR
	{
		LIST *l;
		
		l = make_list(TYPE_UCHAR, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	_IDENT_USHORT
	{
		LIST *l;
		
		l = make_list(TYPE_USHORT, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	_IDENT_ULONG
	{
		LIST *l;
		
		l = make_list(TYPE_ULONG, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	_IDENT_VOID
	{
		LIST *l;
		
		l = make_list(TYPE_VOID, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
|	Identifier
	{
		LIST *l;
		
		l = make_list(TYPE_IDENT, $1);
		OUT_OF_MEM(l);
		
		$$ = l;
	}
;

%%

void
yyerror(char *s)
{
	errors++;
	printf("line %i: %s", yylinecount, s);
	
	if (strstr(s, "parse error"))
		printf(" near token \"%s\"", yytext);
	
	printf("\n");
}