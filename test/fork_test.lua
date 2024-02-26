local fork = require('fork')
local assert = require('assert')
local signal = require('signal')
local sleep = require('time.sleep')
local getpid = require('getpid')

local function test_fork()
    -- test that fork child process
    local pid = assert(getpid())
    local p = assert(fork())
    if p:is_child() then
        assert.match(p, '^fork.process: ', false)
        assert.equal(p:pid(), getpid())
        assert.equal(p:ppid(), pid)
        os.exit()
    else
        assert.match(p, '^fork.child: ', false)
        assert.greater(p:pid(), pid)
        assert.equal(p:ppid(), pid)
    end
end

local function test_wait()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123
        os.exit(123)
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

local function test_waitpid()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123
        sleep(0.5)
        os.exit(123)
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

local function test_wait_untraced()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123 after sig continued
        assert(signal.kill(signal.SIGSTOP))
        os.exit(123)
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

local function test_wait_continued()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123 after sig continued
        assert(signal.kill(signal.SIGSTOP))
        sleep(0.01)
        os.exit(123)
    end
    local pid = p:pid()
    sleep(0.01)

    -- test that res.sigcont=true
    local pp = assert(fork())
    if pp:is_child() then
        -- test that send SIGCONT signal after 100ms
        sleep(0.1)
        assert(signal.kill(signal.SIGCONT, pid))
        os.exit()
    end
    local res, werr, again = p:waitpid(nil, 'continued')
    assert.equal(res, {
        pid = pid,
        sigcont = true,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

local function test_wait_sigterm()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit with sigterm after 100ms
        sleep(0.1)
        assert(signal.kill(signal.SIGTERM))
        os.exit(123)
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

local function test_kill()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit with sigterm after 100ms
        sleep(0.1)
        os.exit(123)
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

test_fork()
test_wait()
test_waitpid()
test_wait_untraced()
test_wait_continued()
test_wait_sigterm()
test_kill()
