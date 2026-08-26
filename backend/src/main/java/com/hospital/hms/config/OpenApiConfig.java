package com.hospital.hms.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI hmsOpenApi() {
        return new OpenAPI().info(new Info()
                .title("Hospital Management System API")
                .version("1.0.0")
                .description("ADBMS project - REST API over the hospital_management schema"));
    }
}
