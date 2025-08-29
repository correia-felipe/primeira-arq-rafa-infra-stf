variable "region"  { 
    type = string 
    default = "us-east-1" 
}
variable "incoming_bucket_name" { 
    type = string 
    default = "primeira-arq-rafa-incoming-847623453769"
}

variable "glue_job_a" { 
    type = string 
    default = "etapa2" 
}
variable "glue_job_b" { 
    type = string 
    default = "iceberglab-v1-tblproperties" 
}


variable "project" { 
    type = string 
    default = "rafa-infra-stf" 
}
variable "env"     { 
    type = string 
    default = "dev" 
    }