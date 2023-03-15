import os, json
d = os.path.dirname(os.path.realpath(__file__))
j = lambda x: os.path.join(d, x)
x = open(j("vim-lua.txt"),'rt').read().split('\n')
y = open(j("vim-opts.txt"),'rt').read().split('\n')

a = {}
def add(w, k, v):
    if w.get(k[0]) is None:
        w[k[0]] = {}
    if len(k) == 1:
        w[k[0]] = v
    else:
        add(w[k[0]], k[1:], v)

for w in x:
    if w:
        if w.startswith('function/'):
            t, ar, n = w.split('/')
            add(a, {'type'})
        else:
            t, n = w.split('/')

