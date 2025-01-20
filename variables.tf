variable "start_module" {
  description = "Used to start operation of module (actually to create route-switcher timer trigger)"
  type        = bool
  default     = false
}

variable "folder_id" {
  description = "Folder id for route-switcher infrastructure"
  type        = string
  default     = null
}

variable "route_table_folder_list" {
  description = "List of folders id with route tables protected by route-switcher"
  type        = list(string)
  default     = []
}

variable "route_table_list" {
    description = "List of route tables id which are protected by route-switcher"
    type = list(string)
    default     = []
}

variable "router_healthcheck_port" {
  description = "Healthchecked tcp port of routers"
  type        = number
  default     = null
}

variable "back_to_primary" {
  description = "Back to primary router after its recovery"
  type        = bool
  default     = true
}

variable "routers" {
  description = "List of routers. For each router specify its healtchecked ip address with subnet, list of router interfaces with ip addresses used as next hops in route tables and corresponding backup peer router ip adresses."
  type = list(object({
    vm_id = string # vm id for router, required for primary router and backup router if 'router_security_groups' value is used
    healthchecked_ip = string  # ip address which will be checked by NLB to obtain router status. Usually located in management network.
    healthchecked_subnet_id = string # subnet id of healthchecked ip address
    interfaces = list(object({
      own_ip = string           # ip address of router interface
      backup_peer_ip = string   # ip address of backup router, which will be used to switch next hop for a static route in case of a router failure
    })) 
  }))
  default = []
}

variable "route_switcher_sa_roles" {
  description = "Roles that are needed for route-switcher service account"
  type        = list(string)
  default = ["load-balancer.privateAdmin", "serverless.functions.invoker", "storage.editor", "monitoring.editor"]
}

variable "cron_interval" {
  description = "Interval in minutes for launching route-switcher function. If changing default value manually change cron_expression value in route_switcher_trigger accordingly to specified interval."
  type = number
  default = 1
}

variable "router_healthcheck_interval" {
  description = "Interval in seconds for checking routers status using NLB healthcheck. Changing interval to value lower than 10 sec is not recommended. If changing default values additional test is recommended for failure scenarios."
  type = number
  default = 60
}

variable "router_security_groups" {
  description = "List of router security groups applied to primary and backup routers. Used with NLB/ALB to emulate Active/Standby traffic processing, e.g. for IPSec VPN Gateways. If primary router fails backup router network interfaces will be updated with 'primary_security_group_ids' list of security groups."
  type = list(object({
    interface_index = number # index of network interface, e.g. 1 
    primary_security_group_ids = list(string) # list of security group ids for primary router
    backup_security_group_ids = list(string) # list of security group ids for backup router
  }))
  default = []
}
