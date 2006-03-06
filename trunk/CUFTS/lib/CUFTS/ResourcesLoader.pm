## CUFTS::ResourcesLoader
##
## Copyright Todd Holbrook - Simon Fraser University (2003)
##
## This file is part of CUFTS.
##
## CUFTS is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free
## Software Foundation; either version 2 of the License, or (at your option)
## any later version.
##
## CUFTS is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along
## with CUFTS; if not, write to the Free Software Foundation, Inc., 59
## Temple Place, Suite 330, Boston, MA 02111-1307 USA

package CUFTS::ResourcesLoader;

use strict;

use CUFTS::Resources::ATLA;
use CUFTS::Resources::BioLine;
use CUFTS::Resources::BioMed;
use CUFTS::Resources::BioOne;
use CUFTS::Resources::Blackwell;
use CUFTS::Resources::blank;
use CUFTS::Resources::Cambridge;
use CUFTS::Resources::CH_PCI;
use CUFTS::Resources::Chicago;
use CUFTS::Resources::CrossRef;
use CUFTS::Resources::Dekker;
use CUFTS::Resources::DOAJ;
use CUFTS::Resources::EBSCO_CINAHL;
use CUFTS::Resources::EBSCO_EJS;
use CUFTS::Resources::EBSCO_Generic;
use CUFTS::Resources::EBSCO_II;
use CUFTS::Resources::EBSCO;
use CUFTS::Resources::Elsevier_CNSLP;
use CUFTS::Resources::Elsevier;
use CUFTS::Resources::Emerald;
use CUFTS::Resources::Erudit;
use CUFTS::Resources::Extenza;
use CUFTS::Resources::Gale_CWI;
use CUFTS::Resources::Gale;
use CUFTS::Resources::GenericJournal;
use CUFTS::Resources::GenericJournalDOI;
use CUFTS::Resources::Highwire;
use CUFTS::Resources::History_Coop;
use CUFTS::Resources::IEEE;
use CUFTS::Resources::III;
use CUFTS::Resources::Ingenta;
use CUFTS::Resources::IngentaConnect;
use CUFTS::Resources::JSTOR;
use CUFTS::Resources::Karger;
use CUFTS::Resources::Kluwer;
use CUFTS::Resources::Lexis_Nexis_AC;
use CUFTS::Resources::MetaPress;
use CUFTS::Resources::Micromedia_CNS;
use CUFTS::Resources::Micromedia;
use CUFTS::Resources::Muse;
use CUFTS::Resources::NRC;
use CUFTS::Resources::OCLC;
use CUFTS::Resources::Ovid;
use CUFTS::Resources::Oxford;
#use CUFTS::Resources::PCI;
use CUFTS::Resources::Proquest_CNS;
use CUFTS::Resources::Proquest;
use CUFTS::Resources::ProquestMicromedia;
use CUFTS::Resources::PubMedCentral;
use CUFTS::Resources::SageCSA;
use CUFTS::Resources::SIRSI;
use CUFTS::Resources::Springer;
use CUFTS::Resources::Swets;
use CUFTS::Resources::Wiley;
use CUFTS::Resources::Wilson;

1;
