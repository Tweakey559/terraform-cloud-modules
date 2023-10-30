######################################################################
# Default VPC
######################################################################

resource "sbercloud_vpc" "this" {
  count = var.is_vpc_create ? 1 : 0

  name = var.name_suffix != "" ? format("%s-%s", var.vpc_name, var.name_suffix) : var.vpc_name
  cidr = var.vpc_cidr_block

  enterprise_project_id = var.enterprise_project_id
}

data "sbercloud_vpcs" "this" {
  count = length(var.query_vpc_names) > 0 ? 1 : 0
}

######################################################################
# All subnets under VPC resource
######################################################################

resource "sbercloud_vpc_subnet" "this" {
  count = var.is_vpc_create && length(var.subnets_configuration) > 0 ? length(var.subnets_configuration) : 0

  vpc_id = sbercloud_vpc.this[0].id

  name        = var.name_suffix != "" ? format("%s-%s", lookup(element(var.subnets_configuration, count.index), "name"), var.name_suffix) : lookup(element(var.subnets_configuration, count.index), "name")
  description = lookup(element(var.subnets_configuration, count.index), "description")
  cidr        = lookup(element(var.subnets_configuration, count.index), "cidr")
  gateway_ip  = cidrhost(lookup(element(var.subnets_configuration, count.index), "cidr"), 1)
  ipv6_enable = lookup(element(var.subnets_configuration, count.index), "ipv6_enabled")
  dhcp_enable = lookup(element(var.subnets_configuration, count.index), "dhcp_enabled")
  dns_list    = lookup(element(var.subnets_configuration, count.index), "dns_list")

  tags = merge(
    { "Name" = var.name_suffix != "" ? format("%s-%s", lookup(element(var.subnets_configuration, count.index), "name"), var.name_suffix) : lookup(element(var.subnets_configuration, count.index), "name")},
    lookup(element(var.subnets_configuration, count.index), "tags")
  )
}

data "sbercloud_vpc_subnets" "this" {
  count = length(var.query_subnet_names) > 0 ? 1 : 0
}

######################################################################
# Default security group
######################################################################

resource "sbercloud_networking_secgroup" "this" {
  count = var.is_security_group_create ? 1 : 0

  name                 = var.name_suffix != "" ? format("%s-secgroup", var.name_suffix) : var.security_group_name
  description          = var.security_group_description
  delete_default_rules = true

  enterprise_project_id = var.enterprise_project_id
}

data "sbercloud_networking_secgroups" "this" {
  count = length(var.query_security_group_names) > 0 ? 1 : 0
}

######################################################################
# Default security group rule
######################################################################

# Allow ECSs in the security group to which this rule belongs to communicate with each other
resource "sbercloud_networking_secgroup_rule" "in_v4_self_group" {
  count = var.is_security_group_create ? 1 : 0

  security_group_id = sbercloud_networking_secgroup.this[0].id
  ethertype         = "IPv4"
  direction         = "ingress"
  remote_group_id   = sbercloud_networking_secgroup.this[0].id
}

######################################################################
# Custom Security Group Rules
######################################################################

resource "sbercloud_networking_secgroup_rule" "this" {
  count = var.is_security_group_create && length(var.security_group_rules_configuration) > 0 ? length(var.security_group_rules_configuration) : 0

  security_group_id = sbercloud_networking_secgroup.this[0].id

  description      = lookup(element(var.security_group_rules_configuration, count.index), "description")
  direction        = lookup(element(var.security_group_rules_configuration, count.index), "direction")
  ethertype        = lookup(element(var.security_group_rules_configuration, count.index), "ethertype")
  protocol         = lookup(element(var.security_group_rules_configuration, count.index), "protocol")
  ports            = lookup(element(var.security_group_rules_configuration, count.index), "ports")
  remote_ip_prefix = lookup(element(var.security_group_rules_configuration, count.index), "remote_group_id") == null ? lookup(element(var.security_group_rules_configuration, count.index), "remote_ip_prefix") : null
  remote_group_id  = lookup(element(var.security_group_rules_configuration, count.index), "remote_group_id")
  action           = lookup(element(var.security_group_rules_configuration, count.index), "action")
  priority         = lookup(element(var.security_group_rules_configuration, count.index), "priority")
}

resource "sbercloud_vpc_address_group" "this" {
  count = var.is_security_group_create && length(var.remote_address_group_rules_configuration) > 0 ? length(var.remote_address_group_rules_configuration) : 0

  name      = var.name_suffix != "" ? format("%s-address-group-%d", var.name_suffix, count.index) : var.security_group_name
  addresses = lookup(element(var.remote_address_group_rules_configuration, count.index), "remote_addresses")
}

resource "sbercloud_networking_secgroup_rule" "remote_address_group" {
  count = var.is_security_group_create && length(var.remote_address_group_rules_configuration) > 0 ? length(var.remote_address_group_rules_configuration) : 0

  security_group_id = sbercloud_networking_secgroup.this[0].id

  description             = lookup(element(var.remote_address_group_rules_configuration, count.index), "description")
  direction               = lookup(element(var.remote_address_group_rules_configuration, count.index), "direction")
  ethertype               = lookup(element(var.remote_address_group_rules_configuration, count.index), "ethertype")
  protocol                = lookup(element(var.remote_address_group_rules_configuration, count.index), "protocol")
  ports                   = lookup(element(var.remote_address_group_rules_configuration, count.index), "ports")
  remote_address_group_id = sbercloud_vpc_address_group.this[count.index].id
  action                  = lookup(element(var.remote_address_group_rules_configuration, count.index), "action")
  priority                = lookup(element(var.remote_address_group_rules_configuration, count.index), "priority")
}
