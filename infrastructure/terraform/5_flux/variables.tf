variable "github_owner" {
  type        = string
  description = "github owner"
}

variable "repository_name" {
  type        = string
  description = "github repository name"
}

variable "branch" {
  type        = string
  default     = "main"
  description = "branch name"
}

variable "target_path" {
  type        = string
  description = "flux sync target path"
}
