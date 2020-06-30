variable "my_ip" {
  description = "an IP address to allow traffic from"
}

variable "key_name" {
  default     = "default"
  description = "SSH key name for Vault and Consul instances"
}

variable "owner" {
  description = "value of owner tag on EC2 instances"
}

variable "ttl" {
  description = "value of ttl tag on EC2 instances"
}
