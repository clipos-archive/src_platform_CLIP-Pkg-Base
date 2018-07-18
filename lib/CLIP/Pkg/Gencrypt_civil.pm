# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2008-2018 ANSSI. All Rights Reserved.
package CLIP::Pkg::Gencrypt;
use strict;
use Exporter;

our @ISA=qw(Exporter);
our @EXPORT=qw($g_dev_cert $g_ctrl_cert $g_dev_crl $g_ctrl_crl $g_dev_trusted_ca $g_ctrl_trusted_ca);

our $g_dev_cert = "./etc/clip_update/keys/certs_dev"; # (-k)
our $g_ctrl_cert = "./etc/clip_update/keys/certs_ctrl"; # (-K)
our $g_dev_crl = "./etc/clip_update/keys/crl_dev"; # (-l)
our $g_ctrl_crl = "./etc/clip_update/keys/crl_ctrl"; # (-L)
our $g_dev_trusted_ca = "./etc/clip_update/keys/certs_dev/trusted_ca_dev.pem"; # (-t)
our $g_ctrl_trusted_ca = "./etc/clip_update/keys/certs_ctrl/trusted_ca_ctrl.pem"; # (-T)
