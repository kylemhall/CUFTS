## CUFTS::ResourcesLoader
##
## Copyright Todd Holbrook - Simon Fraser University (2003)
##
## This file is part of CUFTS.
##
## CUFTS is free software you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free
## Software Foundation either version 2 of the License, or (at your option)
## any later version.
##
## CUFTS is distributed in the hope that it will be useful, but WITHOUT ANY
## WARRANTY without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along
## with CUFTS if not, write to the Free Software Foundation, Inc., 59
## Temple Place, Suite 330, Boston, MA 02111-1307 USA

package CUFTS::ResourcesLoader;

use strict;


my @resource_modules;

BEGIN {

    @resource_modules = qw(
        ATLA
        BioLine
        BioMed
        BioOne
        Blackwell
        BlackwellCOPPUL
        blank
        Cambridge
        CH_PCI
        Chicago
        CrossRef
        Dekker
        DOAJ
        EBSCO_CINAHL
        EBSCO_EJS
        EBSCO_Generic
        EBSCO_II
        EBSCO
        Elsevier_CNSLP
        Elsevier
        Emerald
        Erudit
        Extenza
        Gale_CWI
        Gale_II
        Gale
        GenericJournal
        GenericJournalDOI
        Google::GoogleSearch
        Highwire
        HighwireFree
        History_Coop
        IEEE
        III
        Ingenta
        IngentaConnect
        JournalAuth
        JSTOR
        Karger
        Kluwer
        Lexis_Nexis_AC
        LexisNexisAcademic
        MetaPress
        Micromedia_CNS
        Micromedia
        Muse
        NRC
        OCLC
        Ovid
        OvidLinking
        Ovid_LWW
        Oxford
        Proquest
        ProquestMicromedia
        PubMed
        PubMedCentral
        SageCSA
        SIRSI
        Springer
        Taylor
        Swets
        Wiley
        WileyBackfile
        Wilson
    );

    # ElsevierEurope
    # PCI

    foreach my $module ( @resource_modules ) {
        my $load_module = "CUFTS::Resources::${module}.pm";
        $load_module =~ s{::}{/}xsmg;
        require $load_module;
    }
}

sub list_modules {
    my ( $class ) = @_;
    return @resource_modules;
}


1;
