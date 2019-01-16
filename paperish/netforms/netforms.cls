%
% netforms.cls
%
%

%----------------------------------------------------------------------
% Identify class
%
\NeedsTeXFormat{LaTeX2e}[1999/12/01]
\ProvidesClass{netforms}%
    [2015/10/07 v0.01.0 %
    netforms.cls NET formgs class %
    based on msvreport.cls]

%----------------------------------------------------------------------
% Class options
%
% netcommon.sty
\DeclareOption*{%
    \PassOptionsToPackage{\CurrentOption}{tumlang}
}%
% netforms.cls
% Process options
\ProcessOptions\relax

%----------------------------------------------------------------------
% Load base class report and required packages
%
\LoadClassWithOptions{article}
\RequirePackage{tumlang}
\RequirePackage{tumcontact}
\RequirePackage{legacylogos}
\RequirePackage{xparse}
\RequirePackage{geometry}
\RequirePackage{amsbsy}
\RequirePackage{amsmath}
\RequirePackage{amssymb}
\RequirePackage{amsthm}
\RequirePackage{setspace}
\RequirePackage{adjustbox}
\RequirePackage{ifthen}
\RequirePackage{netforms}

%----------------------------------------------------------------------
% Fonts
%
\RequirePackage[scaled]{helvet}
\RequirePackage{inconsolata}
\renewcommand\familydefault{\sfdefault}
\RequirePackage{sfmath}% Takes care of math mode in general
\RequirePackage[Euler]{upgreek}% That + renews give meaningful greek letters
% helvet font.

% Make helvet the default for all
\renewcommand\rmdefault{ptm}%
\renewcommand\sfdefault{phv}%
\renewcommand\ttdefault{pcr}%

% Kill that all if you wanna use timesmath
\renewcommand{\alpha}{\upalpha}
\renewcommand{\beta}{\upbeta}
\renewcommand{\gamma}{\upgamma}
\renewcommand{\delta}{\updelta}
\renewcommand{\epsilon}{\upepsilon}
\renewcommand{\zeta}{\upzeta}
\renewcommand{\eta}{\upeta}
\renewcommand{\theta}{\uptheta}
\renewcommand{\kappa}{\upkappa}
\renewcommand{\lambda}{\uplambda}
\renewcommand{\mu}{\upmu}
\renewcommand{\nu}{\upnu}
\renewcommand{\xi}{\upxi}
\renewcommand{\pi}{\uppi}
\renewcommand{\rho}{\uprho}
\renewcommand{\sigma}{\upsigma}
\renewcommand{\tau}{\uptau}
\renewcommand{\phi}{\upphi}
\renewcommand{\chi}{\upchi}
\renewcommand{\psi}{\uppsi}
\renewcommand{\omega}{\upomega}
\renewcommand{\Gamma}{\Upgamma}
\renewcommand{\Delta}{\Updelta}
\renewcommand{\Theta}{\Uptheta}
\renewcommand{\Lambda}{\Uplambda}
\renewcommand{\Xi}{\Upxi}
\renewcommand{\Pi}{\Uppi}
\renewcommand{\Phi}{\Upphi}
\renewcommand{\Psi}{\Uppsi}
\renewcommand{\Omega}{\Upomega}


%----------------------------------------------------------------------
% Document commands
%

%\DeclareBoolOption{BA}
%\DeclareBoolOption{MA}
%\DeclareBoolOption{IDP}
%\DeclareBoolOption{SEP}
%\DeclareBoolOption{Diplom}
%\DeclareBoolOption{HiWi}
%\DeclareBoolOption{other}
\newif{\ifnetforms@type@HiWi}
\newif{\ifnetforms@type@BA}
\newif{\ifnetforms@type@MA}
\newif{\ifnetforms@type@IDP}
\newif{\ifnetforms@type@SEP}
\newif{\ifnetforms@type@Diplom}
\newif{\ifnetforms@type@other}

%\netforms@bafalse%
%\netforms@otherfalse%

\def\@other{other}
\def\@ba{ba}

%\def\netforms@student{\@ifnextchar[\@netforms@student{\netforms@student[]}}
%\def\student{\@ifnextchar[\@student{\student[]}}
%\define@cmdkeys[netforms]{student}{vorname,nachname,anrede}[test]

\define@boolkey[netforms]{type}{BA}{\def\netforms@type{Bachelor's Thesis}}
\define@boolkey[netforms]{type}{MA}{\def\netforms@type{Masters's Thesis}}
\define@boolkey[netforms]{type}{IDP}{\def\netforms@type{Interdisziplin\"ares Projekt}}
\define@boolkey[netforms]{type}{SEP}{\def\netforms@type{Systementwicklungsprojekt}}
\define@boolkey[netforms]{type}{Diplom}{\def\netforms@type{Diplomarbeit}}


\DeclareDocumentCommand{\netformsetinfo}{m m m m}{%
	\setkeys[netforms]{type}{#1=true}
	\setkeys[netforms]{student}{#2}
	\def\netforms@title@english{#3}
	\def\netforms@title@german{#4}
}


\DeclareDocumentCommand{\typesetAnmeldung}{}{%
	\netforms@anmeldung@header
	\netforms@anmeldung@ts@info

	\vskip.5cm
	\netforms@anmeldung@title

	\vskip.5cm
	\netforms@anmeldung@footer
}

\DeclareDocumentCommand{\typesetVertrag}{}{%
	\netforms@net@header

	\vskip.5cm
	\netforms@vertrag@content

	\vskip.5cm
	\netforms@net@footer
}

\DeclareDocumentCommand{\typesetAufnahme}{}{%
	\netforms@net@header

	\vskip.5cm
	\netforms@aufnahme@content

	\vskip.5cm
	\netforms@aufnahme@footer
}

\setlength\parindent{0pt}


\endinput
