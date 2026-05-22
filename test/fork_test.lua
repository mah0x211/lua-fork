require('luacov')
local testcase = require('testcase')
local exit = require('testcase.exit').exit
local assert = require('assert')
local fork = require('fork')
local signal = require('signal')
local sleep = require('time.sleep')
local getpid = require('getpid')
local waitpid_fn = require('waitpid')
local new_process = require('fork.process')

function testcase.fork()
    -- test that fork child process
    local pid = assert(getpid())
    local p = assert(fork())
    if p:is_child() then
        assert.match(p, '^fork.process: ', false)
        assert.equal(p:pid(), getpid())
        assert.equal(p:ppid(), pid)
        exit()
    else
        assert.match(p, '^fork.child: ', false)
        assert.greater(p:pid(), pid)
        assert.equal(p:ppid(), pid)
    end
end

function testcase.fork_syscall_error()
    -- test that fork returns nil, err when fork_syscall fails
    local orig_syscall = package.loaded['fork.syscall']
    local orig_fork = package.loaded['fork']
    package.loaded['fork.syscall'] = function()
        return nil, 'mock_error'
    end
    package.loaded['fork'] = nil

    local mock_fork = require('fork')
    local p, err = mock_fork()
    assert.is_nil(p)
    assert.equal(err, 'mock_error')

    package.loaded['fork.syscall'] = orig_syscall
    package.loaded['fork'] = orig_fork
end

function testcase.fork_syscall_again()
    -- test that fork returns nil, nil, true when fork_syscall returns again
    local orig_syscall = package.loaded['fork.syscall']
    local orig_fork = package.loaded['fork']
    package.loaded['fork.syscall'] = function()
        return nil, nil, true
    end
    package.loaded['fork'] = nil

    local mock_fork = require('fork')
    local p, err, again = mock_fork()
    assert.is_nil(p)
    assert.is_nil(err)
    assert.is_true(again)

    package.loaded['fork.syscall'] = orig_syscall
    package.loaded['fork'] = orig_fork
end

function testcase.wait()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123
        exit(123)
    end
    local pid = p:pid()

    -- test that child process exit with code 123
    local res, err = assert(p:wait())
    assert.equal(res, {
        pid = pid,
        exit = 123,
    })
    assert.is_nil(err)

    -- test that pid will be negative integer after exit
    assert.equal(p:pid(), -pid)

    -- test that return error after exit
    res, err = p:wait()
    assert.is_nil(res)
    assert.is_nil(err)
end

function testcase.waitpid()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123
        sleep(0.5)
        exit(123)
    end
    local pid = p:pid()

    -- test that return timeout=true
    local res, err, timeout = p:waitpid(0.01)
    assert.is_nil(res)
    assert.is_nil(err)
    assert.is_true(timeout)

    -- test that child process exit with code 123
    res, err, timeout = assert(p:waitpid())
    assert.equal(res, {
        pid = pid,
        exit = 123,
    })
    assert.is_nil(err)
    assert.is_nil(timeout)

    -- test that pid will be negative integer after exit
    assert.equal(p:pid(), -pid)

    -- test that return all nil after exit
    res, err, timeout = p:waitpid()
    assert.is_nil(res)
    assert.is_nil(err)
    assert.is_nil(timeout)
end

function testcase.wait_untraced()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123 after sig continued
        assert(signal.kill(signal.SIGSTOP))
        exit(123)
    end
    local pid = p:pid()

    -- test that res.sigstop=SIGSTOP
    local res, werr, again = p:waitpid(nil, 'untraced')
    assert.equal(res, {
        pid = pid,
        sigstop = signal.SIGSTOP,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

function testcase.wait_continued()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123 after sig continued
        assert(signal.kill(signal.SIGSTOP))
        sleep(0.01)
        exit(123)
    end
    local pid = p:pid()
    sleep(0.01)

    -- test that res.sigcont=true
    local pp = assert(fork())
    if pp:is_child() then
        -- test that send SIGCONT signal after 100ms
        sleep(0.1)
        assert(signal.kill(signal.SIGCONT, pid))
        exit()
    end
    local res, werr, again = p:waitpid(nil, 'continued')
    assert.equal(res, {
        pid = pid,
        sigcont = true,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

function testcase.wait_sigterm()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit with sigterm after 100ms
        sleep(0.1)
        assert(signal.kill(signal.SIGTERM))
        exit(123)
    end
    local pid = p:pid()

    -- test that return again=true
    local res, werr, again = p:waitpid()
    assert.equal(res, {
        pid = pid,
        exit = 128 + signal.SIGTERM,
        sigterm = signal.SIGTERM,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

function testcase.kill()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit with sigterm after 100ms
        sleep(0.1)
        exit(123)
    end
    local pid = p:pid()

    -- test that error if invalid signal
    local ok, err = p:kill(-987654321)
    assert.is_false(ok)
    assert.match(err, 'EINVAL')

    -- test that return sigterm=SIGTERM
    ok, err = p:kill()
    assert.is_true(ok)
    assert.is_nil(err)

    -- test that return again=true
    local res = assert(p:waitpid())
    assert.equal(res, {
        pid = pid,
        exit = 128 + signal.SIGTERM,
        sigterm = signal.SIGTERM,
    })

    -- test that return ESRCH after exit
    ok, err = p:kill()
    assert.is_false(ok)
    assert.is_nil(err)
end

function testcase.process_methods()
    local p = new_process()
    assert.match(p, '^fork.process: ', false)
    assert.is_true(p:is_child())
    assert.equal(p:pid(), getpid())
    assert.is_int(p:ppid())

    -- test that error if invalid signal
    local ok, err = p:kill(-987654321)
    assert.is_false(ok)
    assert.match(err, 'EINVAL')

    -- test that raise signal (use SIGUSR1 with SIG_IGN to avoid termination)
    assert(signal.ignore(signal.SIGUSR1))
    ok, err = p:kill('SIGUSR1')
    signal.default(signal.SIGUSR1)
    assert.is_true(ok)
    assert.is_nil(err)
end

function testcase.child_kill_esrch()
    local p = assert(fork())
    if p:is_child() then
        exit()
    end
    local pid = p:pid()

    -- reap the child directly so that p.cpid is still positive
    local res = assert(waitpid_fn(pid))
    assert.equal(res.exit, 0)

    -- test that kill returns false/nil when the process is already reaped (ESRCH)
    local ok, err = p:kill()
    assert.is_false(ok)
    assert.is_nil(err)

    -- test that cpid was negated
    assert.equal(p:pid(), -pid)
end
