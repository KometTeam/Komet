package protocol

const Version = 10

const (
	CmdRequest  = 0
	CmdOK       = 1
	CmdNotFound = 2
	CmdError    = 3
)

const (
	OpPing             = 1
	OpSessionInit      = 6
	OpLogin            = 19
	OpLogout           = 20
	OpConfig           = 22
	OpAuthCheckPass    = 115
	OpContactInfo      = 32
	OpChatInfo         = 48
	OpChatMark         = 50
	OpMsgSend          = 64
	OpNotifMessage     = 128
	OpNotifTyping      = 129
	OpNotifMark        = 130
	OpNotifContact     = 131
	OpNotifPresence    = 132
	OpNotifChat        = 135
	OpNotifCallStart   = 137
	OpNotifCallHistory = 165
	OpQrCreate         = 288
	OpQrStatus         = 289
	OpQrFinish         = 291
)
