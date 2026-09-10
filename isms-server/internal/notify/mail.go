package notify

import (
	"context"
	"fmt"
	"mime"
	"net"
	"net/smtp"
	"os"
	"strconv"
	"strings"
)

type smtpMailer struct {
	host string
	port int
	user string
	pass string
	from string
}

func SMTPFromEnv() Mailer {
	host := strings.TrimSpace(os.Getenv("SMTP_HOST"))
	from := strings.TrimSpace(os.Getenv("SMTP_FROM"))
	if host == "" || from == "" {
		return nil
	}
	port := 587
	if raw := strings.TrimSpace(os.Getenv("SMTP_PORT")); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			port = parsed
		}
	}
	return &smtpMailer{
		host: host,
		port: port,
		user: strings.TrimSpace(os.Getenv("SMTP_USER")),
		pass: os.Getenv("SMTP_PASSWORD"),
		from: from,
	}
}

func (m *smtpMailer) Send(_ context.Context, to, subject, body string) error {
	if m == nil || to == "" {
		return nil
	}
	addr := net.JoinHostPort(m.host, strconv.Itoa(m.port))
	var auth smtp.Auth
	if m.user != "" {
		auth = smtp.PlainAuth("", m.user, m.pass, m.host)
	}
	msg := []byte(fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s",
		m.from, to, mime.QEncoding.Encode("utf-8", subject), body))
	return smtp.SendMail(addr, auth, m.from, []string{to}, msg)
}
