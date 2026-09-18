variable "subnet_type" {
  description = "Subnet Type"
  type        = list(string)
  default     = []
}
variable "cidr_header" {
  description = "Network CIDR"
  type        = string
  default     = ""
}
variable "owner" {
  description = "Owner Name"
  type        = string
  default     = ""
}
variable "env_type" {
  description = "Environment"
  type        = string
  default     = ""
}
variable "create_nat_gateway" {
  description = "NAT Gateway의 생성 여부(true-생성 / false-미생성)"
  type        = bool
  default     = true
}
variable "ssh_key" {
  description = "SSH Key"
  type        = string
  default     = ""
}
