package com.hospital.hms.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hospital.hms.common.dto.ApiResponse;
import com.hospital.hms.security.jwt.JwtAuthenticationFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final ObjectMapper objectMapper;

    /**
     * The ObjectMapper is injected, not constructed here. Spring's instance
     * carries the JavaTimeModule and the write-dates-as-timestamps=false
     * setting from application.properties; a bare {@code new ObjectMapper()}
     * has neither, and would render the timestamp on these two error bodies as
     * a numeric array while every other response used an ISO string.
     */
    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter,
                          ObjectMapper objectMapper) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
        this.objectMapper = objectMapper;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // Only the two token-issuing endpoints are anonymous.
                        // /auth/me and /auth/logout need a principal, so they
                        // must stay authenticated - "/auth/**" would let an
                        // anonymous caller reach them with principal == null.
                        .requestMatchers("/auth/login", "/auth/refresh").permitAll()
                        .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()
                        .requestMatchers("/actuator/health").permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .anyRequest().authenticated())
                // Without these two handlers Spring Security answers BOTH
                // "you did not sign in" and "you signed in but may not do this"
                // with 403, which leaves a client unable to tell a missing or
                // expired token from a genuine permission problem. 401 tells the
                // caller to re-authenticate; 403 tells them not to bother.
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(this::writeUnauthorized)
                        .accessDeniedHandler(this::writeForbidden))
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    private void writeUnauthorized(HttpServletRequest request, HttpServletResponse response,
                                   AuthenticationException ex) throws IOException {
        writeError(response, HttpStatus.UNAUTHORIZED,
                "Authentication required: supply a valid Bearer token");
    }

    private void writeForbidden(HttpServletRequest request, HttpServletResponse response,
                                AccessDeniedException ex) throws IOException {
        writeError(response, HttpStatus.FORBIDDEN,
                "You do not have permission to perform this action");
    }

    /** Same ApiResponse envelope the controllers use, so clients parse one shape. */
    private void writeError(HttpServletResponse response, HttpStatus status, String message)
            throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getWriter(), ApiResponse.error(message));
    }

    /**
     * Must agree with however the DATABASE writes password_hash - see
     * {@link MysqlSha256PasswordEncoder} for why this is not BCrypt.
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new MysqlSha256PasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}
