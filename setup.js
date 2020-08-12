const {spawn} = require('child_process')

const execShellCommand = (cmd) => {
  return new Promise((resolve, reject) => {
    const process = spawn(cmd, [], { shell: '/bin/bash' })
    let stdout = ""
    process.stdout.on('data', (data) => {
      console.log(data.toString())
      stdout += data.toString()
    })

    process.stderr.on('data', (data) => {
      console.error(data.toString())
    })

    process.on('exit', (code) => {
      if (code !== 0) {
        reject(new Error(code))
      }
      resolve(stdout)
    })
  }).catch(function (e) {
    console.log("Promise rejected.")
    console.error(e)
  })
}

execShellCommand(__dirname+'/setup.sh')