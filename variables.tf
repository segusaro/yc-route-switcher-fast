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
    vm_id = optional(string) # vm id for router, required for scenario of switching security groups between routers
    healthchecked_ip = string  # ip address which will be checked by NLB to obtain router status. Usually located in management network.
    healthchecked_subnet_id = string # subnet id of healthchecked ip address
    primary = optional(bool, false)           # true if router is primary, required for scenario of switching security groups between routers
    interfaces = list(object({
      # 'own_ip', 'backup_peer_ip' attributes required for interface if its ip adress is used as next hop in route table
      own_ip = optional(string)           # ip address of router interface
      backup_peer_ip = optional(string)   # ip address of backup router, which will be used to switch next hop for a static route in case of a router failure
      index = optional(number) # index of network interface, e.g. 1, required for scenario of switching security groups between routers
      security_group_ids = optional(list(string)) # list of security group ids, required for scenario of switching security groups between routers
    })) 
  }))
  default = []
}

variable "route_switcher_sa_roles" {
  description = "Roles that are needed for route-switcher service account"
  type        = list(string)
  default = ["load-balancer.privateAdmin", "serverless.functions.invoker", "storage.editor", "monitoring.editor", "compute.editor"]
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

variable "security_group_folder_list" {
  description = "List of folders with security groups which should be switched between primary and backup routers in case of a router failure. Required for scenario of switching security groups between routers."
  type        = list(string)
  default = []
}
