variable "asg_name" {
  type    = string
}

variable "upstream_port" {
  type    = number
}

variable "health_check_path" {
  type    = string
}

variable "tags" {
  type = map
  default = {}
}

variable "instance_type" {
  type = string
  default = "t3a.nano"
}